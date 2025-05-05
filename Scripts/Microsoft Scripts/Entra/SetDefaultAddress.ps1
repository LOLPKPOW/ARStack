# === Load Config ===
$configPath = "C:\ARStack\Configurations\Microsoft Configurations\onboarding-defaults.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    return
}
$config = Get-Content $configPath | ConvertFrom-Json

# === Connect to Microsoft Graph ===
Connect-MgGraph -Scopes "User.ReadWrite.All"

# === Get All Users and Patch Address ===
$users = Get-MgUser -All

foreach ($user in $users) {
    $patchBody = @{
        streetAddress   = $config.streetAddress
        city            = $config.city
        state           = $config.state
        postalCode      = $config.postalCode
        country         = $config.country
        businessPhones  = @($config.businessPhone)
        officeLocation  = $config.officeLocation
    } | ConvertTo-Json -Depth 3

    try {
        Invoke-MgGraphRequest -Method PATCH `
            -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
            -Body $patchBody `
            -ContentType "application/json"

        Write-Host "Updated $($user.DisplayName)"
    } catch {
        Write-Warning "Failed to update $($user.DisplayName): $($_.Exception.Message)"
    }
}
