# Import Modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups

# Connect
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"

# Group map
$groupMap = @{
    "1"  = @{ Name = "Accessioning Users"; GroupId = "68de1814-a872-41f8-a2d4-6163b012fe92" }
    "2"  = @{ Name = "Billing and Credentialing Users"; GroupId = "76d9697c-6383-449b-b713-fa7eefff0739" }
    "3"  = @{ Name = "IT Users"; GroupId = "56fc8af0-5cdf-432a-a404-9331fbef6300" }
    "4"  = @{ Name = "Lab Users"; GroupId = "9df8a939-0f2a-4f62-8c21-986ab4d6bc26" }
    "5"  = @{ Name = "Logistics Users"; GroupId = "aacdd6e8-7f23-4490-b098-fc7121c7d543" }
    "6"  = @{ Name = "Management Users"; GroupId = "45ae352a-0536-4779-ba26-baec9e30b61a" }
    "7"  = @{ Name = "Pathologist Users"; GroupId = "5bbff3d6-753a-4c7a-b036-a272d131d7a4" }
    "8"  = @{ Name = "Sales Users"; GroupId = "36b00b23-e64a-4399-9533-cc4b9151cc3e" }
    "9"  = @{ Name = "Skin Users"; GroupId = "4c52794c-9109-4610-ae9d-a190d46d7e36" }
    "10" = @{ Name = "Slide Assignment Users"; GroupId = "cb68b2c6-b6aa-45d4-b981-2c91110e6c41" }
    "11" = @{ Name = "StoolDX Users"; GroupId = "3a85b629-1961-44d5-9c86-c35045e0a662" }
}

# Fixed info
$Domain = "apaths.onmicrosoft.com"
$Password = "TempP@ssword123!"
$Phone = "501-225-1400"
$Street = "5328 Northshore Cove"
$City = "North Little Rock"
$State = "Arkansas"
$PostalCode = "72118"
$Country = "United States"
$LicenseSkuId = "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46"

# Read CSV
do {
    $CSVPath = Read-Host "Enter full path to CSV file (e.g., C:\Path\To\new_users.csv)"
    if (-not (Test-Path $CSVPath)) {
        Write-Host "File not found. Try again." -ForegroundColor Red
    }
} until (Test-Path $CSVPath)

$users = Import-Csv -Path $CSVPath

foreach ($u in $users) {
    $FirstName = $u.FirstName
    $LastName = $u.LastName
    $DisplayName = "$FirstName $LastName"
    $JobTitle = $u.JobTitle
    $DepartmentChoice = $u.DepartmentIndex

    if (-not $groupMap.ContainsKey($DepartmentChoice)) {
        Write-Host "Invalid department index for $DisplayName. Skipping..." -ForegroundColor Red
        continue
    }

    $Department = $groupMap[$DepartmentChoice].Name -replace ' Users$', ''
    $GroupId = $groupMap[$DepartmentChoice].GroupId
    $baseUpn = ($FirstName.Substring(0,1) + $LastName).ToLower()
    $UserPrincipalName = "$baseUpn@$Domain"

    $counter = 2
    while (Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'") {
        $UserPrincipalName = "$baseUpn$counter@$Domain"
        $counter++
    }

    $user = New-MgUser -AccountEnabled:$true `
        -DisplayName $DisplayName `
        -MailNickname ($UserPrincipalName.Split("@")[0]) `
        -UserPrincipalName $UserPrincipalName `
        -PasswordProfile @{ Password = $Password; ForceChangePasswordNextSignIn = $true } `
        -UsageLocation "US" `
        -GivenName $FirstName `
        -Surname $LastName

    if ($null -eq $user) {
        Write-Host "User creation failed for $DisplayName. Skipping..." -ForegroundColor Red
        continue
    }

    # PATCH additional attributes
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
        mobilePhone = $Phone
    } | ConvertTo-Json -Depth 3

    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
        -Body $patchBody -ContentType "application/json"

    # Assign license
    $licenseBody = @{
        addLicenses = @(@{ skuId = $LicenseSkuId })
        removeLicenses = @()
    } | ConvertTo-Json -Depth 3

    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" `
        -Body $licenseBody -ContentType "application/json"

    # Add to group
    New-MgGroupMember -GroupId $GroupId -BodyParameter @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
    }

    Write-Host "Onboarded $DisplayName ($UserPrincipalName)" -ForegroundColor Green
}
