# 0) Retrieve Automation Variables
$automationCertName  = Get-AutomationVariable -Name "ExchangeAutomationCert"
$toEmail             = Get-AutomationVariable -Name "ToEmail"
$fromEmail             = Get-AutomationVariable -Name "FromEmail"
$exchangeAppId       = Get-AutomationVariable -Name "ExchangeAppId"
$tenantId            = Get-AutomationVariable -Name "TenantId"
$orgDomain         = Get-AutomationVariable -Name "OrgDomain"
$sharePointDomain  = Get-AutomationVariable -Name "SharePointDomain"
$sitePath          = Get-AutomationVariable -Name "SharePointSitePath"


# 1) Authenticate to Azure (Managed Identity)
Connect-AzAccount -Identity

# 2) Retrieve the certificate
$cert = Get-AutomationCertificate -Name $automationCertName
if (-not $cert) {
    Write-Error "Certificate '$automationCertName' not found."
    exit 1
}
Write-Output "Certificate '$automationCertName' retrieved."

# 3) Connect to Exchange Online
Write-Output "Connecting to Exchange Online..."
try {
    Connect-ExchangeOnline `
      -AppId       $exchangeAppId `
      -Certificate $cert `
      -Organization $orgDomain
    Write-Output "Exchange Online connection successful."
} catch {
    Write-Error "ExchangeOnline auth failed: $_"
    exit 1
}

# 4) Fetch Unified Audit Logs & convert to CSV
Write-Output "Fetching Unified Audit Logs..."
$logs = Search-UnifiedAuditLog `
    -StartDate (Get-Date).AddDays(-1) `
    -EndDate   (Get-Date) `
    -ResultSize 5000
Write-Output "Retrieved $($logs.Count) records."
$csvContent = $logs | ConvertTo-Csv -NoTypeInformation | Out-String

# 5) Connect to Microsoft Graph
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph `
      -AppId       $exchangeAppId `
      -Certificate $cert `
      -TenantId    $tenantId `
      -NoWelcome
    Write-Output "Microsoft Graph connection successful."
} catch {
    Write-Error "Graph auth failed: $_"
    exit 1
}

# 6) Discover default document library drive
$siteDomain = $sharePointDomain
Write-Output "Fetching default document library drive..."
$driveInfo = Invoke-MgGraphRequest `
  -Method GET `
  -Uri    "https://graph.microsoft.com/v1.0/sites/${siteDomain}:${sitePath}:/drive"
if (-not $driveInfo.id) {
    throw "Could not find default document library drive"
}
$driveId = $driveInfo.id
Write-Output "Default library drive ID is $driveId."

# 7) Prepare nested folder path and file name
$logFileName = "UnifiedAuditLogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$year  = (Get-Date).Year
$month = "{0:D2}" -f (Get-Date).Month
$day   = "{0:D2}" -f (Get-Date).Day

$relativePath = "/Audit Logs/$year/$month/$day/$logFileName"
$escapedPath  = [Uri]::EscapeUriString($relativePath)
$uploadUri    = "https://graph.microsoft.com/v1.0/drives/${driveId}/root:${escapedPath}:/content"

# 8) Upload the CSV to SharePoint
Write-Output "Uploading CSV to SharePoint at path: $uploadUri"
$response = Invoke-MgGraphRequest `
  -Method      PUT `
  -Uri         $uploadUri `
  -ContentType "text/csv" `
  -Body        $csvContent `
  -Verbose
Write-Output "Upload succeeded. File URL: $($response.webUrl)"

# 9) List folder contents to verify
$folderPath = "/Audit Logs"
$children = Invoke-MgGraphRequest `
  -Method GET `
  -Uri    "https://graph.microsoft.com/v1.0/drives/${driveId}/root:$([Uri]::EscapeUriString($folderPath)):/children"
Write-Output "Files in 'Audit Logs':"
$children.value | ForEach-Object { Write-Output " - $($_.name) (ID: $($_.id))" }

# 10) Send confirmation email via Microsoft Graph
$emailBody = @{
    Message = @{
        Subject = "Audit Log Upload Complete"
        Body = @{
            ContentType = "Text"
            Content     = "$logFileName was generated and uploaded to SharePoint successfully at $(Get-Date)."
        }
        ToRecipients = @(
            @{ EmailAddress = @{ Address = $toEmail } }
        )
    }
    SaveToSentItems = $false
}

Send-MgUserMail -UserId $fromEmail -BodyParameter $emailBody
