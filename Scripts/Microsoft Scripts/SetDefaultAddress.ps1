Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = Get-MgUser -All

foreach ($user in $users) {
    $patchBody = @{
        streetAddress   = "Street Address"
        city            = "City"
        state           = "State"
        postalCode      = "Postal Code"
        country         = "United States"
        businessPhones  = @("Business Phone")
        officeLocation  = "Office Location"
    } | ConvertTo-Json -Depth 3

    Invoke-MgGraphRequest -Method PATCH `
        -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
        -Body $patchBody `
        -ContentType "application/json"

    Write-Host "→ Updated $($user.DisplayName)"
}
