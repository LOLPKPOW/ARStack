# === OnboardUser.ps1 ===

# === Load Config ===
$configPath = "C:\ARStack\Configurations\Microsoft Configurations\onboarding-defaults.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config not found at $configPath"
    return
}
$config = Get-Content $configPath | ConvertFrom-Json

$domain     = $config.domain
$logDir     = "C:\ARStack\AutomationLogs\logs"
$logFile    = "$logDir\OnboardingLog.csv"
$Password = $config.defaultPassword

# Import required modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module ExchangeOnlineManagement

# Connect to Microsoft Graph
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"
} catch {
    Write-Host "Could not connect to Graph: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Prompt for user details
$FirstName = Read-Host "Enter First Name"
$LastName = Read-Host "Enter Last Name"
$DisplayName = "$FirstName $LastName"
$JobTitle = Read-Host "Enter Job Title"

# Department selection
$departments = @("Accessioning", "Billing", "Coding", "Customer Service", "GI", "IT", "Lab", "Logistics", "Management", "Pathologists", "Sales", "Slide Assignments", "StoolIDX", "Support")
for ($i = 0; $i -lt $departments.Count; $i++) {
    Write-Host "$($i+1). $($departments[$i])"
}
$choice = Read-Host "Choose department"
if (-not $departments[$choice - 1]) {
    Write-Host "Invalid department choice. Exiting." -ForegroundColor Red
    return
}
$Department = $departments[$choice - 1]

# Generate UPN
$baseUpn = ($FirstName.Substring(0,1) + $LastName).ToLower()
$UserPrincipalName = "$baseUpn@$domain"
$counter = 2
while (Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'") {
    $UserPrincipalName = "$baseUpn$counter@$domain"
    $counter++
}

if (-not $Password) {
    Write-Error "No default password defined in config. Aborting."
    return
}

# Create the user
$passwordProfile = @{
    Password = $config.defaultPassword
    ForceChangePasswordNextSignIn = $true
}

$user = New-MgUser -AccountEnabled:$true `
    -DisplayName $DisplayName `
    -MailNickname ($UserPrincipalName.Split("@")[0]) `
    -UserPrincipalName $UserPrincipalName `
    -PasswordProfile $passwordProfile `
    -UsageLocation $config.usageLocation `
    -GivenName $FirstName `
    -Surname $LastName


if ($null -eq $user) {
    Write-Host "User creation failed. Aborting." -ForegroundColor Red
    return
}

# Patch profile details
$patchBody = @{
    jobTitle        = $JobTitle
    department      = $Department
    streetAddress   = $config.streetAddress
    city            = $config.city
    state           = $config.state
    postalCode      = $config.postalCode
    country         = $config.country
    businessPhones  = @($config.businessPhone)
    officeLocation  = $config.officeLocation
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
    -Body $patchBody -ContentType "application/json"

# Assign license
$licensePatch = @{
    addLicenses = @(@{ skuId = $config.licenseSkuId })
    removeLicenses = @()
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
    -Body $licensePatch -ContentType "application/json"

Write-Host "Assigned Microsoft 365 license to $DisplayName"

# Optional Global Admin
if ($Department -eq "IT") {
    $giveGlobal = Read-Host "Grant Global Admin to this IT user? (Y/N)"
    if ($giveGlobal -match "^[Yy]") {
        try {
            Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.AccessAsUser.All"
            $gaRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Global Administrator'"
            New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $user.Id -RoleDefinitionId $gaRole.Id -DirectoryScopeId "/"
            Write-Host "Global Admin assigned to $UserPrincipalName"
        } catch {
            Write-Warning "Failed to assign Global Admin: $_"
        }
    }
}

# Ensure logs directory
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Write log
$log = [PSCustomObject]@{
    Timestamp    = (Get-Date)
    DisplayName  = $DisplayName
    UPN          = $UserPrincipalName
    Department   = $Department
    GlobalAdmin  = ($giveGlobal -match "^[Yy]")
    License      = "Microsoft 365 Business Premium"
    Password     = $Password
}
$log | Export-Csv -Path $logFile -Append -NoTypeInformation

# Summary
Write-Host "`Onboarding complete for $DisplayName ($UserPrincipalName)" -ForegroundColor Green
Write-Host "Department: $Department"
Write-Host "Password: $Password"
Write-Host "Log written to: $logFile"
