# === OffboardUser.ps1 ===

# === Load Config ===
$configPath = "C:\ARStack\Configurations\Microsoft Configurations\onboarding-defaults.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    return
}
$config = Get-Content $configPath | ConvertFrom-Json

$logDir        = "C:\ARStack\AutomationLogs\logs"
$logFile       = "$logDir\OffboardingLog.csv"
$groupId       = $config.offboardingGroupId
$licenseSkuId  = $config.licenseSkuId

# === Import Required Modules ===
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module ExchangeOnlineManagement

# === Connect to Microsoft Graph ===
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"
} catch {
    Write-Host ("Could not connect to Graph: " + $_.Exception.Message) -ForegroundColor Red
    return
}

# === Prompt for UPN ===
$UserPrincipalName = Read-Host "Enter UPN of user to offboard"

# === Get User ===
try {
    $user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -ErrorAction Stop
} catch {
    Write-Error ("User not found: " + $UserPrincipalName)
    return
}

# === Disable the Account ===
Set-MgUser -UserId $user.Id -AccountEnabled:$false
Write-Host ("Account disabled for " + $UserPrincipalName)

# === Revoke Sessions ===
Revoke-MgUserSignInSession -UserId $user.Id
Write-Host ("Sessions revoked for " + $UserPrincipalName)

# === Remove License ===
$licensePayload = @{
    addLicenses    = @()
    removeLicenses = @($licenseSkuId)
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
    -Body $licensePayload -ContentType "application/json"
Write-Host ("License removed for " + $UserPrincipalName)

# === Convert Mailbox to Shared ===
try {
    Connect-ExchangeOnline -ShowBanner:$false
    Set-Mailbox -Identity $UserPrincipalName -Type Shared
    Write-Host ("Mailbox converted to shared for " + $UserPrincipalName)
} catch {
    Write-Warning ("Could not convert mailbox to shared: " + $_)
}

# === Clear Profile Attributes ===
$nullFields = @{
    jobTitle       = $null
    department     = $null
    officeLocation = $null
    streetAddress  = $null
    city           = $null
    state          = $null
    postalCode     = $null
    country        = $null
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
    -Body $nullFields -ContentType "application/json"
Write-Host ("Profile fields cleared for " + $UserPrincipalName)

# === Add to Offboarded Users Group ===
if ($groupId) {
    try {
        Add-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
        Write-Host ("Added to offboarded users group: " + $groupId)
    } catch {
        Write-Warning ("Failed to add to offboarded group: " + $_)
    }
}

# === Delete the User from Entra ===
try {
    Remove-MgUser -UserId $user.Id -Confirm:$false
    Write-Host ("User deleted from Entra ID: " + $UserPrincipalName)
} catch {
    Write-Warning ("Failed to delete user: " + $_)
}


# === Log Offboarding ===
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$log = [PSCustomObject]@{
    Timestamp = (Get-Date)
    UPN       = $UserPrincipalName
    Action    = "Offboarded"
}
$log | Export-Csv -Path $logFile -Append -NoTypeInformation

# === Final Output ===
Write-Host ("Offboarding complete for " + $UserPrincipalName) -ForegroundColor Green
Write-Host ("Log written to: " + $logFile)
