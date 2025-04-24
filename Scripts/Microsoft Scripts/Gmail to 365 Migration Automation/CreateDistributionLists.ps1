Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline
# ---------------------------
# Replace with your CSV path
# ---------------------------
$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Migration Setup Files\groups_description.csv"
$logPath = "C:\AutomationLogs\logs\DL_Creation_Results_$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

# Ensure log directory exists
if (-not (Test-Path "C:\AutomationLogs\logs")) {
    New-Item -Path "C:\AutomationLogs\logs" -ItemType Directory -Force | Out-Null
}

$groups = Import-Csv -Path $csvPath

foreach ($group in $groups) {
    $email = $group.email
    $name = $group.name
    $description = $group.description

    if (-not $name) {
        $name = $email.Split("@")[0]
    }

    if (-not (Get-DistributionGroup -Identity $email -ErrorAction SilentlyContinue)) {
        $params = @{
            Name                = $name
            PrimarySmtpAddress = $email
        }

        if ($description -and $description -ne 'nan') {
            $params['Notes'] = $description
        }
        if ($email -notlike "*@apaths.onmicrosoft.com") {
            $msg = "Skipped DL (unsupported domain): $email"
            Write-Host $msg
            $msg | Out-File -Append -FilePath $logPath
            continue
        }        
        try {
            New-DistributionGroup @params
            $msg = "Created DL: $email"
        } catch {
            $msg = "Failed to create DL: $email - $($_.Exception.Message)"
        }
    } else {
        $msg = "DL already exists: $email"
    }

    Write-Host $msg
    $msg | Out-File -Append -FilePath $logPath
}