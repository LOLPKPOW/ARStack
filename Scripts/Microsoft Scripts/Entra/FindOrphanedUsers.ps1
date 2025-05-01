# Load configuration
$configPath = "config\orphaned-user-check.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json

Connect-MgGraph

$allUsers = Get-MgUser -All
$groupedUserIds = @()

# Use group IDs from config
$departmentGroupIds = $config.departmentGroupIds

foreach ($groupId in $departmentGroupIds) {
    try {
        $members = Get-MgGroupMember -GroupId $groupId -All
        $groupedUserIds += $members.Id
    } catch {
        Write-Warning "Failed to get members for group $groupId: $_"
    }
}

# Find users not in any department group
$orphanedUsers = $allUsers | Where-Object { $groupedUserIds -notcontains $_.Id }

# Get output path from config or ask via Read-Host
$outputPath = $config.outputCsvPath
if (-not $outputPath) {
    $outputPath = Read-Host "Enter path for orphaned user report CSV"
}

$orphanedUsers |
    Select-Object DisplayName, UserPrincipalName |
    Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Orphaned user report written to: $outputPath"