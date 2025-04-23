Connect-MgGraph

$allUsers = Get-MgUser -All
$groupedUserIds = @()

# Grab IDs from all your department groups
$departmentGroupIds = @(
    "68de1814-a872-41f8-a2d4-6163b012fe92",  # Accessioning
    "76d9697c-6383-449b-b713-fa7eefff0739",  # Billing
    "56fc8af0-5cdf-432a-a404-9331fbef6300",  # IT
    "9df8a939-0f2a-4f62-8c21-986ab4d6bc26",  # Lab
    "aacdd6e8-7f23-4490-b098-fc7121c7d543",  # Logistics
    "45ae352a-0536-4779-ba26-baec9e30b61a",  # Management
    "5bbff3d6-753a-4c7a-b036-a272d131d7a4",  # Pathologists
    "36b00b23-e64a-4399-9533-cc4b9151cc3e",  # Sales
    "4c52794c-9109-4610-ae9d-a190d46d7e36",  # Skin
    "cb68b2c6-b6aa-45d4-b981-2c91110e6c41",  # Slide Assignment
    "3a85b629-1961-44d5-9c86-c35045e0a662",  # StoolDX
    "b0218722-caaa-4d98-9d77-3473077def03",  # Support
    "ba83d93f-95aa-4976-9d45-5c35a03db869",  # Offboarded Users
    "5bd870ed-f67e-4a5f-a726-4581d0e2cfe8"   # Service Accounts
)

foreach ($groupId in $departmentGroupIds) {
    $members = Get-MgGroupMember -GroupId $groupId -All
    $groupedUserIds += $members.Id
}

# Find users not in any group
$orphanedUsers = $allUsers | Where-Object { $groupedUserIds -notcontains $_.Id }

# Output to CSV for review
$orphanedUsers | Select DisplayName, UserPrincipalName | Export-Csv -Path ".\ex_employees_staging_checkup.csv" -NoTypeInformation
