$Username = "LocalAdmin"
$Password = ConvertTo-SecureString "ARStackDefault246!@" -AsPlainText -Force
$Group = "Administrators"

# Check if the user already exists
if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    Write-Output "🆕 Creating local user '$Username'"
    New-LocalUser -Name $Username -Password $Password -FullName "Local Admin" -Description "Created by Intune script" -PasswordNeverExpires -AccountNeverExpires
} else {
    Write-Output "✅ User '$Username' already exists"
}

# Check if the user is already a member of the Administrators group
$existing = Get-LocalGroupMember -Group $Group -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Username -or $_.Name -like "*\$Username" }

if (-not $existing) {
    Write-Output "👑 Adding '$Username' to the Administrators group"
    Add-LocalGroupMember -Group $Group -Member $Username
} else {
    Write-Output "✅ '$Username' is already in the Administrators group"
}

