Import-Module ExchangeOnlineManagement
# === ApplySingleLitHold.ps1 ===
param (
    [Parameter(Mandatory=$true)][string]$Email
)

$skuId = "05e9a617-0261-4cee-bb44-138d3ef5d965"  # E3 SKU

try {
    Write-Host "Assigning E3 license to $Email..."
    Set-MsolUserLicense -UserPrincipalName $Email -AddLicenses $skuId -ErrorAction Stop

    Write-Host "Applying Litigation Hold to $Email..."
    Set-Mailbox $Email -LitigationHoldEnabled $true -LitigationHoldDuration 2550 -ErrorAction Stop

    Write-Host "Lit hold applied and E3 assigned to $Email"
    [PSCustomObject]@{
        Email = $Email
        HoldApplied = $true
        LicenseStatus = "E3 Assigned"
    } | Export-Csv -Path "C:\AutomationLogs\SingleLitHoldLog.csv" -Append -NoTypeInformation

} catch {
    Write-Host "Error: ${($_.Exception.Message)}"
    [PSCustomObject]@{
        Email = $Email
        HoldApplied = $false
        LicenseStatus = "Error: $($_.Exception.Message)"
    } | Export-Csv -Path "C:\AutomationLogs\SingleLitHoldLog.csv" -Append -NoTypeInformation
}