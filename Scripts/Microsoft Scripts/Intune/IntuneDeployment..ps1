# === IntuneDeployment.ps1 ===

# Load modules
Import-Module IntuneBackupAndRestore -ErrorAction Stop

# Optional: Load AzureAD if needed
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Write-Host "→ AzureAD module not found, installing..." -ForegroundColor Yellow
    Install-Module AzureAD -Force -Scope CurrentUser
}
Import-Module AzureAD

# Connect to Graph
Write-Host "→ Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MSGraph

# Define required groups
$requiredGroups = @(
    @{
        DisplayName = "All Devices - Not Servers"
        MailNickname = "AllDevicesNotServers"
        IsDynamic = $true
        MembershipRule = '(device.deviceOSType -eq "Windows") -and (NOT (device.deviceOSVersion -contains "Server"))'
    },
    @{
        DisplayName = "Allow USB"
        MailNickname = "AllowUSB"
        IsDynamic = $false
    },
    @{
        DisplayName = "Block USB"
        MailNickname = "BlockUSB"
        IsDynamic = $false
    }
)

foreach ($group in $requiredGroups) {
    $existing = Get-AzureADGroup -Filter "DisplayName eq '$($group.DisplayName)'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "✓ Group '$($group.DisplayName)' already exists." -ForegroundColor Green
        continue
    }

    try {
        if ($group.IsDynamic) {
            Write-Host "→ Creating dynamic group: $($group.DisplayName)" -ForegroundColor Yellow
            New-AzureADMSGroup -DisplayName $group.DisplayName `
                -MailEnabled $false `
                -MailNickname $group.MailNickname `
                -SecurityEnabled $true `
                -GroupTypes "DynamicMembership" `
                -MembershipRule $group.MembershipRule `
                -MembershipRuleProcessingState "On" | Out-Null
        } else {
            Write-Host "→ Creating static group: $($group.DisplayName)" -ForegroundColor Yellow
            New-AzureADGroup -DisplayName $group.DisplayName `
                -MailEnabled $false `
                -MailNickname $group.MailNickname `
                -SecurityEnabled $true | Out-Null
        }

        Write-Host "✓ Created group '$($group.DisplayName)'" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to create group '$($group.DisplayName)': $_" -ForegroundColor Red
    }
}

# === Restore Intune Config ===
$baselinePath = "C:\ARStack\Configurations\Intune\Baseline"

Write-Host "`n→ Restoring Intune configuration from: $baselinePath" -ForegroundColor Cyan
Start-IntuneRestoreConfig -Path $baselinePath

Write-Host "→ Restoring Intune group assignments..." -ForegroundColor Cyan
Start-IntuneRestoreAssignments -Path $baselinePath

Write-Host "`Intune baseline deployment complete." -ForegroundColor Green
