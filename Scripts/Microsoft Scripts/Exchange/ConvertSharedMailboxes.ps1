# === Configuration ===
$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Migration Setup Files\OldAccountSharedMailboxConversion.csv"
$logPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Migration Setup Files\OldAccountSharedMailboxConversion_log.csv"
$licenseSkuId = "f245ecc8-75af-4f8e-b61f-27d8114de5f3"  # Microsoft 365 Business Premium

# === Connect ===
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.Read.All"
Connect-ExchangeOnline -UserPrincipalName pwoodward-adm@apaths.onmicrosoft.com

# === Process CSV ===
$users = Import-Csv -Path $csvPath

foreach ($u in $users) {
    $email = $u.convertedEmail.Trim()
    if (-not $email) { continue }

    Write-Host "`nProcessing $email..." -ForegroundColor Cyan
    $status = ""

    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction Stop

        # Assign license
        try {
            $licenseBodyAdd = @{
                addLicenses    = @(@{ skuId = $licenseSkuId })
                removeLicenses = @()
            } | ConvertTo-Json -Depth 3

            Invoke-MgGraphRequest -Method POST `
                -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
                -Body $licenseBodyAdd `
                -ContentType "application/json"

            Write-Host "License Assigned" -ForegroundColor Green
            $status += "License Assigned; "
        } catch {
            $status += "Error Assigning License: $($_.Exception.Message); "
        }

        # Wait for mailbox provisioning (up to 5 minutes)
        $maxAttempts = 6
        $attempt = 1
        $mailbox = $null

        while (-not $mailbox -and $attempt -le $maxAttempts) {
            Write-Host "Checking for mailbox (attempt $attempt of $maxAttempts)..." -ForegroundColor Yellow
            $mailbox = Get-Mailbox -Identity $email -ErrorAction SilentlyContinue
            if (-not $mailbox) {
                Start-Sleep -Seconds 30
                $attempt++
            }
        }

        if ($mailbox) {
            try {
                Set-Mailbox -Identity $email -Type Shared
                Write-Host "Converted to Shared Mailbox" -ForegroundColor Green
                $status += "Converted to Shared; "
            } catch {
                $status += "Error Converting to Shared: $($_.Exception.Message); "
            }
        } else {
            Write-Host "Mailbox not found after $maxAttempts attempts. Skipping conversion." -ForegroundColor Red
            $status += "Failed - Mailbox not found after retry; "
        }

        # Wait before removing license
        Start-Sleep -Seconds 8

        # Remove license
        try {
            $licenseBodyRemove = @{
                addLicenses    = @()
                removeLicenses = @($licenseSkuId)
            } | ConvertTo-Json -Depth 3

            Invoke-MgGraphRequest -Method POST `
                -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
                -Body $licenseBodyRemove `
                -ContentType "application/json"

            Write-Host "License Removed" -ForegroundColor Green
            $status += "License Removed"
        } catch {
            $status += "Error Removing License: $($_.Exception.Message)"
        }

    } catch {
        $status = "User not found or general error: $($_.Exception.Message)"
        Write-Host $status -ForegroundColor Red
    }

    # === Log Line-By-Line to CSV ===
    [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Email     = $email
        Status    = $status
    } | Export-Csv -Path $logPath -Append -NoTypeInformation
}

Write-Host "`nAll done! Log saved to:`n$logPath" -ForegroundColor Green
$successCount = (Import-Csv $logPath | Where-Object { $_.Status -like "*Converted to Shared*" }).Count
$failCount = (Import-Csv $logPath | Where-Object { $_.Status -like "*Error*" }).Count
Write-Host "`nSummary: $successCount converted, $failCount errors" -ForegroundColor Magenta