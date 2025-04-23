$csv = Import-Csv "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\StaleAccounts.csv"
$gamPath = "C:\GAM7\gam.exe"

$suspended = @()
$alreadyActive = @()
$errors = @()

foreach ($user in $csv) {
    $email = $user.Email
    try {
        $info = & $gamPath info user $email
        if ($info -match "Account Suspended:\s+True") {
            Write-Host "Unsuspending $email"
            & $gamPath update user $email suspended off
            $suspended += $email
        } elseif ($info -match "Account Suspended:\s+False") {
            Write-Host "$email is already active"
            $alreadyActive += $email
        } else {
            Write-Host "⚠️ Unknown suspension state for $email"
            $errors += $email
        }
    } catch {
        Write-Host "❌ Error checking/updating $email"
        $errors += $email
    }
}

# Summary
Write-Host "`n=== Summary ==="
Write-Host "Unsuspended: $($suspended.Count)"
Write-Host "Already active: $($alreadyActive.Count)"
Write-Host "Errors: $($errors.Count)"
