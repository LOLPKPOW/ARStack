Import-Module ExchangeOnlineManagement

# === Configuration ===
$inputCsv = "C:\Path\To\AccountsPendingLitHold.csv"
$outputCsv = "C:\AutomationLogs\output\ProcessedLitHolds.csv"
$logPath   = "C:\AutomationLogs\logs\LitHoldApplyLog.csv"
$skuId     = "ENTERPRISEPACK"  # E3 SKU name

# === Connect ===
Connect-MsolService
Connect-ExchangeOnline

# === Init Log ===
if (-not (Test-Path $logPath)) {
    "Email,HoldAlreadySet,HoldApplied,LicenseStatus,Timestamp" | Out-File -FilePath $logPath -Encoding UTF8
}

# === Load Users ===
$allUsers = Import-Csv $inputCsv
$results = @()
$appliedCount = 0

foreach ($user in $allUsers) {
    if ($appliedCount -ge 25) { break }

    $email = $user.Email.Trim()
    if (-not $email) { continue }

    Write-Host "Processing $email..." -ForegroundColor Cyan

    try {
        # Check mailbox existence
        $mailbox = Get-Mailbox -Identity $email -ErrorAction Stop

        if ($mailbox.LitigationHoldEnabled) {
            Write-Host "$email already has litigation hold. Skipping..." -ForegroundColor Gray
            "$email,True,False,Skipped,$(Get-Date -Format 's')" | Out-File -Append -FilePath $logPath -Encoding UTF8
            continue
        }

        # Check if already licensed
        $userLic = Get-MsolUser -UserPrincipalName $email -ErrorAction Stop

        if (-not $userLic.IsLicensed) {
            Write-Host "Assigning E3 license to $email..." -ForegroundColor Yellow
            Set-MsolUserLicense -UserPrincipalName $email -AddLicenses $skuId -ErrorAction Stop
        } else {
            Write-Host "License already assigned to $email — skipping license step." -ForegroundColor Gray
        }

        # Apply litigation hold
        Set-Mailbox -Identity $email -LitigationHoldEnabled $true -LitigationHoldDuration 2550 -ErrorAction Stop
        Write-Host "Litigation hold applied to $email" -ForegroundColor Green

        $appliedCount++
        $results += [PSCustomObject]@{
            Email         = $email
            HoldApplied   = $true
            LicenseStatus = if ($userLic.IsLicensed) { "Already Licensed" } else { "E3 Assigned" }
        }

        "$email,False,True,E3 Assigned,$(Get-Date -Format 's')" | Out-File -Append -FilePath $logPath -Encoding UTF8
    } catch {
        $msg = $_.Exception.Message.Replace("`n", "").Replace("`r", "")
        Write-Host ("Error on {0}: {1}" -f $email, $msg) -ForegroundColor Red
        $results += [PSCustomObject]@{
            Email         = $email
            HoldApplied   = $false
            LicenseStatus = "Error: $msg"
        }
        "$email,False,False,Error: $msg,$(Get-Date -Format 's')" | Out-File -Append -FilePath $logPath -Encoding UTF8
    }
}

# === Export Final Report ===
$results | Export-Csv -Path $outputCsv -NoTypeInformation
Write-Host "`Done. Applied to $appliedCount accounts." -ForegroundColor Green
Write-Host "Results exported to: $outputCsv" -ForegroundColor Cyan
