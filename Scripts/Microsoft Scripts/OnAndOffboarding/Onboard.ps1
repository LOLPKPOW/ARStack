# Import Modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Group mapping
$groupMap = @{
    "1"  = @{ Name = "Accessioning Users"; GroupId = "68de1814-a872-41f8-a2d4-6163b012fe92" }
    "2"  = @{ Name = "Billing and Credentialing Users"; GroupId = "76d9697c-6383-449b-b713-fa7eefff0739" }
    "3"  = @{ Name = "IT Users"; GroupId = "56fc8af0-5cdf-432a-a404-9331fbef6300" }
    "4"  = @{ Name = "Lab Users"; GroupId = "9df8a939-0f2a-4f62-8c21-986ab4d6bc26" }
    "5"  = @{ Name = "Logistics Users"; GroupId = "aacdd6e8-7f23-449b-b098-fc7121c7d543" }
    "6"  = @{ Name = "Management Users"; GroupId = "45ae352a-0536-4779-ba26-baec9e30b61a" }
    "7"  = @{ Name = "Pathologist Users"; GroupId = "5bbff3d6-753a-4c7a-b036-a272d131d7a4" }
    "8"  = @{ Name = "Sales Users"; GroupId = "36b00b23-e64a-4399-9533-cc4b9151cc3e" }
    "9"  = @{ Name = "Skin Users"; GroupId = "4c52794c-9109-4610-ae9d-a190d46d7e36" }
    "10" = @{ Name = "Slide Assignment Users"; GroupId = "cb68b2c6-b6aa-45d4-b981-2c91110e6c41" }
    "11" = @{ Name = "StoolDX Users"; GroupId = "3a85b629-1961-44d5-9c86-c35045e0a662" }
    "12" = @{ Name = "Support Users"; GroupID = "b0218722-caaa-4d98-9d77-3473077def03" }
}

# Prompt for user info
$FirstName = Read-Host "Enter First Name"
$LastName = Read-Host "Enter Last Name"
$DisplayName = "$FirstName $LastName"
$JobTitle = Read-Host "Enter Job Title"
$Domain = "apaths.onmicrosoft.com"

# Department selection
Write-Host "`nChoose a department:"
foreach ($key in $groupMap.Keys | Sort-Object {[int]$_}) {
    Write-Host "$key. $($groupMap[$key].Name)"
}
$DepartmentChoice = Read-Host "Choose department (1-11)"
if (-not $groupMap.ContainsKey($DepartmentChoice)) {
    Write-Host "Invalid department selection. Exiting." -ForegroundColor Red
    return
}
$Department = $groupMap[$DepartmentChoice].Name -replace ' Users$', ''
$GroupId = $groupMap[$DepartmentChoice].GroupId

# Generate base UPN
$baseUpn = ($FirstName.Substring(0,1) + $LastName).ToLower()
$UserPrincipalName = "$baseUpn@$Domain"

# Ensure uniqueness of UPN
$counter = 2
while (Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'") {
    $UserPrincipalName = "$baseUpn$counter@$Domain"
    $counter++
}

# Generate a random password
Add-Type -AssemblyName System.Web
$Password = [System.Web.Security.Membership]::GeneratePassword(12, 3)

# Fixed attributes
$Phone = "501-225-1400"
$Street = "5328 Northshore Cove"
$City = "North Little Rock"
$State = "Arkansas"
$PostalCode = "72118"
$Country = "United States"

# Create the user with required fields
$user = New-MgUser -AccountEnabled:$true `
    -DisplayName $DisplayName `
    -MailNickname ($UserPrincipalName.Split("@")[0]) `
    -UserPrincipalName $UserPrincipalName `
    -PasswordProfile @{ Password = $Password; ForceChangePasswordNextSignIn = $true } `
    -UsageLocation "US" `
    -GivenName $FirstName `
    -Surname $LastName

if ($null -eq $user) {
    Write-Host "User creation failed. Aborting." -ForegroundColor Red
    return
}

# Save user object for later use
$userObject = $user

# Update additional profile fields via direct Graph PATCH
$patchBody = @{
    jobTitle      = $JobTitle
    department    = $Department
    streetAddress = $Street
    city          = $City
    state         = $State
    postalCode    = $PostalCode
    country       = $Country
    businessPhones = @($Phone)
    officeLocation = "North Little Rock"
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
    -Body $patchBody -ContentType "application/json"

# Assign Microsoft 365 Business Premium license
$licensePatch = @{
    addLicenses = @(
        @{
            skuId = "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46"  # Business Premium
        }
    )
    removeLicenses = @()
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
    -Body $licensePatch -ContentType "application/json"
Write-Host "Assigned Microsoft 365 Business Premium to $DisplayName"

# Add to Entra ID group
New-MgGroupMember -GroupId $GroupId -BodyParameter @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
}

# Check if user is in IT and optionally assign Global Admin via Graph
if ($DepartmentChoice -eq "3") {
    Write-Host "IT user detected."

    $giveGlobal = Read-Host "Grant Global Admin to this IT user? (Y/N)"
    if ($giveGlobal -match "^[Yy]") {
        try {
            Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.AccessAsUser.All"
            $gaRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Global Administrator'"
            New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $userObject.Id -RoleDefinitionId $gaRole.Id -DirectoryScopeId "/"
            Write-Host "Global Admin assigned to $($userObject.UserPrincipalName)"
        } catch {
            Write-Host "Failed to assign Global Admin: $_" -ForegroundColor Red
        }
    }
}

# Ensure directory exists
if (-not (Test-Path "C:\AutomationLogs")) {
    New-Item -ItemType Directory -Path "C:\AutomationLogs" | Out-Null
}

# Log onboarding details
$log = [PSCustomObject]@{
    Timestamp      = (Get-Date)
    DisplayName    = $DisplayName
    UPN            = $UserPrincipalName
    Department     = $Department
    GlobalAdmin    = ($giveGlobal -match "^[Yy]")
    License        = "Microsoft 365 Business Premium"
    Password       = $Password
}
try {
    $log | Export-Csv -Path "C:\AutomationLogs\OnboardingLog.csv" -Append -NoTypeInformation
} catch {
    Write-Host "Could not write to onboarding log: $_" -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "Onboarding complete for $DisplayName ($UserPrincipalName)" -ForegroundColor Green
Write-Host "Department: $Department"
Write-Host "Group: $($groupMap[$DepartmentChoice].Name)"
Write-Host "Phone: $Phone"
Write-Host "Address: $Street, $City, $State, $PostalCode"
Write-Host "License: Microsoft 365 Business Premium"
Write-Host "Default Password: $Password"
Write-Host "Log written to: C:\AutomationLogs\OnboardingLog.csv"
