Write-Host "==== ARStack User Management Tool ====" -ForegroundColor Cyan
Write-Host "1. Onboard a new user"
Write-Host "2. Offboard an existing user"
Write-Host "3. Exit"
$choice = Read-Host "Choose an option (1-3)"

switch ($choice) {
    "1" { . "$PSScriptRoot\Onboard.ps1" }
    "2" { . "$PSScriptRoot\Offboard.ps1" }
    default { Write-Host "Goodbye!" }
}
