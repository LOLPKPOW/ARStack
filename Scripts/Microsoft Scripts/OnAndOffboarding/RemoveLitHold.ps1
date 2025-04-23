# === RemoveLitHold.ps1 ===

Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Identity.DirectoryManagement
Import-Module ExchangeOnlineManagement

# Connect to services
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "User.ReadWrite.All"
Connect-ExchangeOnline -ShowBanner:$false

Write-Host ""
Write-Host "WARNING: This process takes time! Estimate 1 minute per 20 users." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Config
$e3SkuId = "05e9a617-0261-4cee-bb44-138d3ef5d965"
$logPath = "C:\AutomationLogs"
$removedLog = "$logPath\RemovedE3Log.csv"
$gapLog = "$logPath\E3WithoutLitHold.csv"
$missingHoldLog = "$logPath\MissingLitHold.csv"

if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

# Stats
$total = 0
$withE3 = 0
$withLitHold = 0
$removed = @()
$gaps = @()
$missingHold = @()

# Get user and shared mailboxes only
$mailboxes = Get-Mailbox -ResultSize Unlimited | Where-Object {
    $_.RecipientTypeDetails -in @("UserMailbox", "SharedMailbox")
}

foreach ($mailbox in $mailboxes) {
    $email = $mailbox.UserPrincipalName
    Write-Host "Checking $email..."
    $total++

    try {
        $user = Get-MgUser -UserId $email -Property "assignedLicenses"
        $hasLitHold = $mailbox.LitigationHoldEnabled
        $hasE3 = $user.assignedLicenses.skuId -contains $e3SkuId

        if ($hasE3) { $withE3++ }
        if ($hasLitHold) { $withLitHold++ }

        if ($hasE3 -and $hasLitHold) {
            Write-Host "E3 Present... Litigation Hold Present... Removing E3 from $email"

            $licenseBody = @{
                addLicenses = @()
                removeLicenses = @($e3SkuId)
            } | ConvertTo-Json -Depth 3

            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$email/assignLicense" `
                -Method POST -Body $licenseBody -ContentType "application/json"

            $removed += $email

        } elseif ($hasE3 -and -not $hasLitHold) {
            Write-Host "E3 assigned but NO Lit Hold on $email"
            $gaps += $email
            $missingHold += $email

        } elseif (-not $hasLitHold) {
            Write-Host "No Litigation Hold on $email"
            $missingHold += $email

        } else {
            Write-Host "No E3 or Lit Hold on $email"
        }

    } catch {
        Write-Host ("Failed to check {0}: {1}" -f $email, $_.Exception.Message) -ForegroundColor Red
    }
}

# === Summary ===
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total Mailboxes Checked: $total"
Write-Host "Users with E3: $withE3"
Write-Host "Users with Litigation Hold: $withLitHold"
Write-Host "Removed E3 from $($removed.Count) users" -ForegroundColor Green
Write-Host "Users with E3 but no Lit Hold: $($gaps.Count)" -ForegroundColor Blue
Write-Host "Mailboxes without Litigation Hold: $($missingHold.Count)" -ForegroundColor Red

if ($gaps.Count -gt 0) {
    Write-Host "`nList of users with E3 but no Lit Hold:" -ForegroundColor Yellow
    $gaps | ForEach-Object { Write-Host "- $_" }
}

# === Logging ===
$removed | ForEach-Object {
    [PSCustomObject]@{ Email = $_; Timestamp = (Get-Date) }
} | Export-Csv -Path $removedLog -NoTypeInformation -Append

$gaps | ForEach-Object {
    [PSCustomObject]@{ Email = $_; Timestamp = (Get-Date) }
} | Export-Csv -Path $gapLog -NoTypeInformation -Append

$missingHold | ForEach-Object {
    [PSCustomObject]@{ Email = $_; Timestamp = (Get-Date) }
} | Export-Csv -Path $missingHoldLog -NoTypeInformation -Append

Write-Host "`nLog written to:" -ForegroundColor Green
Write-Host "  - Removed: $removedLog"
Write-Host "  - Gaps:    $gapLog"
Write-Host "  - Missing Hold: $missingHoldLog"
