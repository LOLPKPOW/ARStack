# === Setup ===
Import-Module ExchangeOnlineManagement

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = "C:\ARStack\AutomationLogs\output\SharedMailboxAccess_$timestamp.csv"

# Ensure output directory exists
$outputDir = Split-Path $outputPath
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

# === Connect to Exchange Online ===
try {
    Connect-ExchangeOnline -ShowBanner:$false
} catch {
    Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
    return
}

# === Get Shared Mailboxes and Permissions ===
$results = @()

$mailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

foreach ($mbx in $mailboxes) {
    $permissions = Get-MailboxPermission -Identity $mbx.Identity | Where-Object {
        $_.User.ToString() -ne "NT AUTHORITY\SELF" -and $_.AccessRights -ne $null
    }

    foreach ($perm in $permissions) {
        $results += [PSCustomObject]@{
            MailboxName   = $mbx.DisplayName
            MailboxUPN    = $mbx.UserPrincipalName
            Permission    = ($perm.AccessRights -join ", ")
            GrantedTo     = $perm.User
            IsInherited   = $perm.IsInherited
        }
    }
}

# === Export to CSV ===
$results | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
Write-Host "Export complete. Saved to: $outputPath"
