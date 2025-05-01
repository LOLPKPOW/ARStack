# === CONFIG ===
$configPath = "C:\ARStack\configurations\Microsoft Configurations\orphaned-massmove.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$csvPath = $config.inputCsvPath
$logPath = "C:\ARStack\AutomationLogs\logs\orphaned-move-log.csv"
$groupId = $config.targetGroupId

# === CONNECT TO GRAPH ===
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "Directory.Read.All"

# === INIT LOG ===
$logResults = @()

# === LOAD AND PROCESS CSV ===
Import-Csv -Path $csvPath | Where-Object { $_.UserPrincipalName -and $_.UserPrincipalName.Trim() -ne "" } | ForEach-Object {
    $email = $_.UserPrincipalName.Trim()
    Write-Host "Processing $email..."
    $status = ""

    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction Stop
        if ($user -and $user.Id) {
            # Add to group
            New-MgGroupMember -GroupId $groupId -BodyParameter @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)" }
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
if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" | Out-Null }
$logResults | Export-Csv -Path $logPath -NoTypeInformation
Write-Host "`nDone! Log saved to:`n$logPath"

