# === OnboardUser.ps1 ===

# Set config paths and values
$domain = "apaths.onmicrosoft.com"
$logDir = "C:\AutomationLogs"
$litHoldScript = "$logDir\ApplySingleLitHold.ps1"
$logFile = "$logDir\OnboardingLog.csv"

# Import required Graph modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups

# Connect to Microsoft Graph
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"
} catch {
    Write-Host "Could not connect to Graph: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Define group mapping
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

# Prompt for user details
$FirstName = Read-Host "Enter First Name"
$LastName = Read-Host "Enter Last Name"
$DisplayName = "$FirstName $LastName"
$JobTitle = Read-Host "Enter Job Title"

Write-Host "`nChoose a department:"
foreach ($key in $groupMap.Keys | Sort-Object {[int]$_}) {
    Write-Host "$key. $($groupMap[$key].Name)"
}
$DepartmentChoice = Read-Host "Choose department (1-12)"
if (-not $groupMap.ContainsKey($DepartmentChoice)) {
    Write-Host "Invalid department selection. Exiting." -ForegroundColor Red
    return
}
$Department = $groupMap[$DepartmentChoice].Name -replace ' Users$', ''
$GroupId = $groupMap[$DepartmentChoice].GroupId

# Generate UPN
$baseUpn = ($FirstName.Substring(0,1) + $LastName).ToLower()
$UserPrincipalName = "$baseUpn@$domain"
$counter = 2
while (Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'") {
    $UserPrincipalName = "$baseUpn$counter@$domain"
    $counter++
}

# Random password
Add-Type -AssemblyName System.Web
$Password = [System.Web.Security.Membership]::GeneratePassword(12, 3)

# Create the user
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

# Patch extra profile attributes
$patchBody = @{
    jobTitle        = $JobTitle
    department      = $Department
    streetAddress   = "5328 Northshore Cove"
    city            = "North Little Rock"
    state           = "Arkansas"
    postalCode      = "72118"
    country         = "United States"
    businessPhones  = @("501-225-1400")
    officeLocation  = "North Little Rock"
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
    -Body $patchBody -ContentType "application/json"

# Assign Microsoft 365 Business Premium license
$licensePatch = @{
    addLicenses = @(@{ skuId = "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46" })
    removeLicenses = @()
} | ConvertTo-Json -Depth 3

Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
    -Body $licensePatch -ContentType "application/json"

Write-Host "Assigned Microsoft 365 Business Premium to $DisplayName"

# Add to group
New-MgGroupMember -GroupId $GroupId -BodyParameter @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
}

# IT Users: Optional Global Admin
if ($DepartmentChoice -eq "3") {
    $giveGlobal = Read-Host "Grant Global Admin to this IT user? (Y/N)"
    if ($giveGlobal -match "^[Yy]") {
        try {
            Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.AccessAsUser.All"
            $gaRole = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Global Administrator'"
            New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $user.Id -RoleDefinitionId $gaRole.Id -DirectoryScopeId "/"
            Write-Host "Global Admin assigned to $UserPrincipalName"
        } catch {
            Write-Host "Failed to assign Global Admin: $_" -ForegroundColor Red
        }
    }
}

# Optionally apply litigation hold
if (Test-Path $litHoldScript) {
    $applyLitHold = Read-Host "Apply E3 + Litigation Hold to $UserPrincipalName? (Y/N)"
    if ($applyLitHold -match "^[Yy]") {
        & $litHoldScript -Email $UserPrincipalName
        Write-Host "`nReminder: Run RemoveLitHold.ps1 weekly to clean up any users that still have E3 licenses after Lit Hold was applied." -ForegroundColor Yellow

    }
} else {
    Write-Host "Litigation Hold script not found. Skipping."
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

# Final summary
Write-Host "`nOnboarding complete for $DisplayName ($UserPrincipalName)" -ForegroundColor Green
Write-Host "Group: $($groupMap[$DepartmentChoice].Name)"
Write-Host "License: Microsoft 365 Business Premium"
Write-Host "Default Password: $Password"
Write-Host "Log written to: $logFile"
