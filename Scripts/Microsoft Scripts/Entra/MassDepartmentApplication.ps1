# === CONFIGURATION ===
$configPath = "C:\ARStack\Configurations\Microsoft Configurations\onboarding-defaults.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$csvPath = $config.inputCsvPath

Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.AccessAsUser.All"

$users = Import-Csv $csvPath

foreach ($user in $users) {
    $upn   = $user.UPN
    $name  = $user.User
    $dept  = $user.Department

    $first, $last = $name -split ' ', 2
    $mailNick     = ($upn -split '@')[0]

    $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue

    if (-not $existing) {
        Write-Host "→ Creating $upn..."

        $createdUser = New-MgUser -AccountEnabled:$true `
            -DisplayName $name `
            -GivenName $first `
            -Surname $last `
            -UserPrincipalName $upn `
            -MailNickname $mailNick `
            -PasswordProfile @{
                ForceChangePasswordNextSignIn = $true
                Password = $config.defaultPassword
            } `
            -UsageLocation $config.usageLocation

        # Build patch body from config defaults
        $patchBody = [ordered]@{
            department     = $dept
            streetAddress  = $config.streetAddress
            city           = $config.city
            state          = $config.state
            postalCode     = $config.postalCode
            country        = $config.country
            businessPhones = @($config.businessPhone)
            officeLocation = $config.officeLocation
        }

        if ($user.JobTitle -and $user.JobTitle.Trim()) {
            $patchBody["jobTitle"] = $user.JobTitle.Trim()
        }

        Invoke-MgGraphRequest -Method PATCH `
            -Uri "https://graph.microsoft.com/v1.0/users/$($createdUser.Id)" `
            -Body ($patchBody | ConvertTo-Json -Depth 3) `
            -ContentType "application/json"
    } else {
        Write-Host "✓ $upn already exists."
    }
}
