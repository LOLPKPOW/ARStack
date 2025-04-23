# === ApplyLitHold.ps1 ===
$inputCsv = "C:\Path\To\StaleAccounts.csv"
$outputCsv = "C:\Path\To\ProcessedLitHolds.csv"
$logPath   = "C:\Path\To\LitHoldApplyLog.csv"
$skuId     = "ENTERPRISEPACK"  # E3 SKU name

# Header for logs
if (-not (Test-Path $logPath)) {
    "Email,HoldAlreadySet,HoldApplied,LicenseStatus,Timestamp" | Out-File -FilePath $logPath -Encoding UTF8
}

# Load all users
$allUsers = Import-Csv $inputCsv
$results = @()
$appliedCount = 0

foreach ($user in $allUsers) {
    if ($appliedCount -ge 25) { break }

    $email = $user.Email
    Write-Host "Processing $email..."

    try {
        $mailbox = Get-Mailbox $email -ErrorAction Stop
        if ($mailbox.LitigationHoldEnabled) {
            Write-Host "$email already has litigation hold. Skipping..."
            "$email,True,False,Skipped,$(Get-Date -Format s)" | Out-File -Append -FilePath $logPath -Encoding UTF8
            continue
        }

        # Apply litigation hold and E3 license
        Set-Mailbox $email -LitigationHoldEnabled $true -LitigationHoldDuration 2550 -ErrorAction Stop
        Set-MsolUserLicense -UserPrincipalName $email -AddLicenses $skuId -ErrorAction Stop

        $appliedCount++
        $results += [PSCustomObject]@{
            Email         = $email
            HoldApplied   = $true
            LicenseStatus = "E3 Assigned"
        }
        "$email,False,True,E3 Assigned,$(Get-Date -Format s)" | Out-File -Append -FilePath $logPath -Encoding UTF8
    } catch {
        $msg = $_.Exception.Message.Replace("`n", "").Replace("`r", "")
        $results += [PSCustomObject]@{
            Email         = $email
            HoldApplied   = $false
            LicenseStatus = "Error: $msg"
        }
        "$email,False,False,Error: $msg,$(Get-Date -Format s)" | Out-File -Append -FilePath $logPath -Encoding UTF8
    }
}

$results | Export-Csv $outputCsv -NoTypeInformation
Write-Host "`nDone. Applied to $appliedCount accounts. Exported to $outputCsv"
