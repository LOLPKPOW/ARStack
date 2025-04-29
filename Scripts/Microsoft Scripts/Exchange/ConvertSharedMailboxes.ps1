Import-Module ExchangeOnlineManagement

# === Configuration ===
$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Migration Setup Files\FullActiveUsersConvertMig.csv"
$logPath = "C:\AutomationLogs\logs\FullActiveUsersConvertMig.csv_log.csv"
$licenseSkuId = "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46"  # Microsoft 365 Business Premium

# === Connect ===
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.Read.All"
Connect-ExchangeOnline

# === Process CSV ===
$users = Import-Csv -Path $csvPath

foreach ($u in $users) {
    $email = $u.EmailAddress.Trim()
    if (-not $email) { continue }

    Write-Host "`nProcessing $email..." -ForegroundColor Cyan
    $status = ""

    try {
        # === Get User via Graph ===
        $user = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction Stop

        # === Check if Already Shared Mailbox ===
        $mailbox = Get-Mailbox -Identity $email -ErrorAction SilentlyContinue
        if ($mailbox -and $mailbox.RecipientTypeDetails -eq "SharedMailbox") {
            Write-Host "Already a Shared Mailbox — checking license" -ForegroundColor Gray
            $status += "Already Shared; "

            # === Check if License is Assigned ===
            if ($user.AssignedLicenses | Where-Object { $_.SkuId -eq $licenseSkuId }) {
                Write-Host "$email already has the Business Premium license, removing it" -ForegroundColor Yellow

                # === Attempt License Removal ===
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
            } else {
                Write-Host "$email does not have the Business Premium license, skipping license removal" -ForegroundColor Gray
                $status += "License not assigned; "
            }

            continue  # Skip to the next user since we don't need to convert the mailbox again.
        }
        # === After license removal check ===
        $mailbox = Get-Mailbox -Identity $email -ErrorAction Stop
        if ($mailbox.RecipientTypeDetails -eq "SharedMailbox") {
            # License removal confirmation step
            $user = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction Stop
            $assignedLicenses = $user.AssignedLicenses
            $licenseAssigned = $assignedLicenses | Where-Object { $_.SkuId -eq $licenseSkuId }

            if (-not $licenseAssigned) {
                Write-Host "License successfully removed for $email" -ForegroundColor Green
            } else {
                Write-Host "License still assigned, attempting to remove again" -ForegroundColor Red
                # Try to remove the license again if it wasn't removed
                try {
                    $licenseBodyRemove = @{
                        addLicenses    = @()
                        removeLicenses = @($licenseSkuId)
                    } | ConvertTo-Json -Depth 3

                    Invoke-MgGraphRequest -Method POST `
                        -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
                        -Body $licenseBodyRemove `
                        -ContentType "application/json"

                    Write-Host "License Removed on Retry" -ForegroundColor Green
                } catch {
                    Write-Host "Error Removing License on Retry: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }


        # === If Not Shared Mailbox, Assign License, Convert to Shared and Remove License ===
        Write-Host "Processing $email to convert mailbox and manage license..." -ForegroundColor Cyan
        $status = ""

        # === Assign License if Not Present ===
        if (-not ($user.AssignedLicenses | Where-Object { $_.SkuId -eq $licenseSkuId })) {
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
        } else {
            Write-Host "License already assigned — skipping" -ForegroundColor Gray
            $status += "License Already Assigned; "
        }

        # === Convert to Shared ===
        Set-Mailbox -Identity $email -Type Shared -ErrorAction Stop
        Write-Host "Converted to Shared Mailbox" -ForegroundColor Green
        $status += "Converted to Shared; "

        # === Wait for a short period to allow the mailbox conversion to propagate ===
        Start-Sleep -Seconds 30  # Adjust this time as necessary

        # === Confirm Mailbox Type is Shared ===
        $mailbox = Get-Mailbox -Identity $email -ErrorAction Stop
        if ($mailbox.RecipientTypeDetails -ne "SharedMailbox") {
            Write-Host "Mailbox type still not Shared — skipping license removal" -ForegroundColor Red
            $status += "Failed - Mailbox type not Shared; "
            continue
        }

        # === Attempt License Removal Regardless ===
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

# === Summary Output ===
Write-Host "`nAll done! Log saved to:`n$logPath" -ForegroundColor Green
$successCount = (Import-Csv $logPath | Where-Object { $_.Status -like "*Converted to Shared*" }).Count
$failCount = (Import-Csv $logPath | Where-Object { $_.Status -like "*Error*" }).Count
Write-Host "`nSummary: $successCount converted, $failCount errors" -ForegroundColor Magenta
