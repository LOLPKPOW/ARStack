# --- Install-ARStackDependencies.ps1 ---
# PowerShell Dependency Installer for ARStack Projects

Write-Host "`n→ Installing required PowerShell modules for ARStack..." -ForegroundColor Cyan

# Ensure PSGallery is trusted
$repoName = "PSGallery"
if ((Get-PSRepository -Name $repoName).InstallationPolicy -ne 'Trusted') {
    Write-Host "→ Trusting PSGallery..."
    Set-PSRepository -Name $repoName -InstallationPolicy Trusted
}

# Microsoft Graph SDK (Core)
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "→ Installing Microsoft.Graph SDK..."
    Install-Module Microsoft.Graph -AllowClobber -Force
}

# Graph Submodules (if specific APIs are needed)
$graphSubModules = @(
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.DeviceManagement",
    "Microsoft.Graph.DeviceManagement.Administration",
    "Microsoft.Graph.DeviceManagement.Configuration"
)

foreach ($mod in $graphSubModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "→ Installing $mod..."
        Install-Module $mod -AllowClobber -Force
    }
}

# Exchange Online (optional)
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement..."
    Install-Module ExchangeOnlineManagement -AllowClobber -Force
}

# IntuneBackupAndRestore (for config backups & restore)
if (-not (Get-Module -ListAvailable -Name IntuneBackupAndRestore)) {
    Write-Host "Installing IntuneBackupAndRestore..."
    Install-Module IntuneBackupAndRestore -AllowClobber -Force
}

# Legacy MSOnline (optional, if needed for backwards compatibility)
if (-not (Get-Module -ListAvailable -Name MSOnline)) {
    Write-Host "→ Installing MSOnline module..."
    Install-Module MSOnline -Force
}

Write-Host "`All ARStack PowerShell modules installed successfully." -ForegroundColor Green
