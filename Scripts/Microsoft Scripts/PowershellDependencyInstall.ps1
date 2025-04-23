# --- ARStack PowerShell Dependency Installer ---
# Installs required modules for Exchange, Intune, Graph, etc.

Write-Host "`nInstalling required PowerShell modules..." -ForegroundColor Cyan

# Repository trust check
$repoName = "PSGallery"
if ((Get-PSRepository -Name $repoName).InstallationPolicy -ne 'Trusted') {
    Write-Host "Trusting PSGallery..."
    Set-PSRepository -Name $repoName -InstallationPolicy Trusted
}

# Install Graph SDK
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installing Microsoft.Graph SDK..."
    Install-Module Microsoft.Graph -AllowClobber -Force
}

# Install Exchange Online Management
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement..."
    Install-Module ExchangeOnlineManagement -AllowClobber -Force
}

# Optionally install MSOnline (legacy, used in some orgs)
if (-not (Get-Module -ListAvailable -Name MSOnline)) {
    Write-Host "Installing MSOnline module..."
    Install-Module MSOnline -Force
}

# Install Intune module (optional for config export)
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Intune)) {
    Write-Host "Installing Microsoft.Graph.Intune (preview)..."
    Install-Module Microsoft.Graph.Intune -AllowClobber -Force
}

Write-Host "`All modules installed successfully!" -ForegroundColor Green
