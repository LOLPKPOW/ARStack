$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Google Drive Audit\userswithnames_final.csv"
$logPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Google Drive Audit\import_log_final.csv"

$officeInfo = @{
    officeLocation = "North Little Rock"
    businessPhones = @("501-225-1400")
    streetAddress  = "5328 Northshore Cove"
    city           = "North Little Rock"
    state          = "Arkansas"
    postalCode     = "72118"
    country        = "United States"
}

$logResults = @()
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Initialize the log file with headers
[PSCustomObject]@{
    Email  = "Email"
    Status = "Status"
} | Export-Csv -Path $logPath -NoTypeInformation -Force

Import-Csv -Path $csvPath | ForEach-Object {
    $email = $_.convertedEmail
    if (-not $email -or -not $email.EndsWith("apaths.onmicrosoft.com")) { return }

    $username    = $email.Split("@")[0]
    $firstName   = $_.'name.givenName'
    $lastName    = $_.'name.familyName'
    $displayName = $_.'name.fullName'

    Write-Host "`nProcessing $email..." -ForegroundColor Cyan
    $status = ""

    $user = Get-MgUser -Filter "UserPrincipalName eq '$email'" -ErrorAction SilentlyContinue

    if (-not $user) {
        try {
            $user = New-MgUser -AccountEnabled:$true `
                -DisplayName $displayName `
                -MailNickname $username `
                -UserPrincipalName $email `
                -GivenName $firstName `
                -Surname $lastName `
                -PasswordProfile @{ Password = "TempP@ssw0rd123!"; ForceChangePasswordNextSignIn = $true } `
                -UsageLocation "US"
            $status = "Created"
        } catch {
            $status = "Error creating: $($_.Exception.Message)"
        }
    } else {
        $status = "Exists"
    }

    if ($user -and $user.Id) {
        try {
            $patchBody = @{
                givenName       = $firstName
                surname         = $lastName
                displayName     = $displayName
                officeLocation  = $officeInfo.officeLocation
                businessPhones  = $officeInfo.businessPhones
                streetAddress   = $officeInfo.streetAddress
                city            = $officeInfo.city
                state           = $officeInfo.state
                postalCode      = $officeInfo.postalCode
                country         = $officeInfo.country
            } | ConvertTo-Json -Depth 3

            Invoke-MgGraphRequest -Method PATCH `
                -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)" `
                -Body $patchBody `
                -ContentType "application/json"

            $status += if ($status -eq "Exists") { "; Updated Info" } else { "; Info Updated" }
        } catch {
            $status += "; Error updating info: $($_.Exception.Message)"
        }
    } else {
        $status += "; No valid user ID for update"
    }

    # Log to console
    Write-Host $status -ForegroundColor Yellow

    # Log to CSV immediately
    [PSCustomObject]@{
        Email  = $email
        Status = $status
    } | Export-Csv -Path $logPath -Append -NoTypeInformation
}

Write-Host "`nDone! Log saved to:`n$logPath" -ForegroundColor Green
