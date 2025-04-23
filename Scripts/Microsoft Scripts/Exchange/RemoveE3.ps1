# === RemoveE3IfHeld.ps1 ===

$inputCsv = "C:\Path\To\ProcessedLitHolds.csv"
$outputCsv = "C:\Path\To\RemoveE3Results.csv"
$skuId = "ENTERPRISEPACK"

# Prepare output
$logResults = @()

Import-Csv $inputCsv | ForEach-Object {
    $email = $_.Email
    Write-Host "Checking $email..."

    try {
        $mailbox = Get-Mailbox $email -ErrorAction Stop
        $hold = $mailbox.LitigationHoldEnabled

        if ($hold) {
            Write-Host "Lit hold confirmed. Removing E3 from $email..."
            Set-MsolUserLicense -UserPrincipalName $email -RemoveLicenses $skuId -ErrorAction Stop

            $logResults += [PSCustomObject]@{
                Timestamp      = (Get-Date)
                Email          = $email
                HoldConfirmed  = $true
                LicenseRemoved = "Success"
                Notes          = ""
            }
        } else {
            Write-Host "Hold not confirmed on $email, skipping"
            $logResults += [PSCustomObject]@{
                Timestamp      = (Get-Date)
                Email          = $email
                HoldConfirmed  = $false
                LicenseRemoved = "Skipped"
                Notes          = "Hold not active"
            }
        }
    } catch {
        Write-Host "❌ Error processing $email: $($_.Exception.Message)"
        $logResults += [PSCustomObject]@{
            Timestamp      = (Get-Date)
            Email          = $email
            HoldConfirmed  = "Error"
            LicenseRemoved = "Error"
            Notes          = $_.Exception.Message
        }
    }
}

$logResults | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "`n✅ Log written to $outputCsv"
