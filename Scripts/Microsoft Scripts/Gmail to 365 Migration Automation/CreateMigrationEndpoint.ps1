# === Load Config ===
$configPath = "C:\ARStack\Configurations\Gmail to 3665 Migration Configurations\create-migration-endpoint.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    return
}
$config = Get-Content $configPath | ConvertFrom-Json

# === Import Module ===
Import-Module ExchangeOnlineManagement

# === Connect to Exchange Online ===
try {
    Connect-ExchangeOnline -UserPrincipalName $config.adminUpn -ShowBanner:$false
} catch {
    Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message)"
    return
}

# === Validate Service Account Key Path ===
if (!(Test-Path $config.serviceAccountKeyPath)) {
    Write-Error "Service account key file not found at $($config.serviceAccountKeyPath)"
    return
}

# === Create Gmail Migration Endpoint ===
try {
    New-MigrationEndpoint -Gmail `
        -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes($config.serviceAccountKeyPath)) `
        -EmailAddress $config.googleAdminEmail `
        -Name $config.migrationEndpointName

    Write-Host "Migration endpoint '$($config.migrationEndpointName)' created successfully."
} catch {
    Write-Error "Failed to create migration endpoint: $($_.Exception.Message)"
}
