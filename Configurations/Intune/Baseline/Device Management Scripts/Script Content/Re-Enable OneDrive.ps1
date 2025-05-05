# Remove the Group Policy kill switch if it exists
$regPath = "HKLM:\Software\Policies\Microsoft\Windows\OneDrive"
if (Test-Path $regPath) {
    Remove-Item -Path $regPath -Recurse -Force
    Write-Output "Removed OneDrive policy key"
} else {
    Write-Output "OneDrive policy key not present"
}

# Optionally restart OneDrive (if installed)
$onedrivePath = "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
if (Test-Path $onedrivePath) {
    Start-Process $onedrivePath -ArgumentList "/background"
    Write-Output "OneDrive started"
}

