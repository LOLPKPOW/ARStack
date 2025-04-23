# === CONFIG ===
$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\ex_employees_staging.csv"
$logPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\ex_employees_staging_log.csv"
$groupId = "ba83d93f-95aa-4976-9d45-5c35a03db869"  # Replace this with the destination Entra group ID

# === CONNECT TO GRAPH ===
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "Directory.Read.All"

# === INIT LOG ===
$logResults = @()

# === LOAD AND PROCESS CSV ===
Import-Csv -Path $csvPath | Where-Object { $_.UserPrincipalName -and $_.UserPrincipalName.Trim() -ne "" } | ForEach-Object {
    $email = $_.UserPrincipalName.Trim()
    Write-Host "Processing $email..." -ForegroundColor Cyan
    $status = ""

    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction Stop
        if ($user -and $user.Id) {
            # Add to group
            New-MgGroupMember -GroupId $groupId -BodyParameter @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
            }
            $status = "Added to Group"
        } else {
            $status = "User not found"
        }
    } catch {
        $status = "Error: $($_.Exception.Message)"
    }

    $logResults += [PSCustomObject]@{
        Email  = $email
        Status = $status
    }
}

# === EXPORT LOG ===
$logResults | Export-Csv -Path $logPath -NoTypeInformation
Write-Host "`nDone! Log saved to:`n$logPath" -ForegroundColor Green
