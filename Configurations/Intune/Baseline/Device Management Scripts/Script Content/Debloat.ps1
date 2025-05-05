# === SETTINGS ===
$AppxToRemove = @(
    "Microsoft.XboxGamingOverlay",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.SkypeApp",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.People",
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingFinance",
    "Microsoft.BingSports",
    "Microsoft.WindowsFeedbackHub"
)

$OEMApps = @(
    "Dell SupportAssist",
    "Dell Update",
    "Dell Digital Delivery",
    "Waves MaxxAudio",
    "SupportAssist Remediation",
    "HP Support Assistant",
    "HP Connection Optimizer",
    "HP JumpStart",
    "HP Client Security Manager",
    "HP Wolf Security",
    "HP Sure Connect"
)

$LogPath = "$env:ProgramData\IntuneScripts\Decrapify.log"
New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null

function Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$ts - $msg"
}

Log "`n===== Starting Decrapify Script ====="

# === OEM Detection ===
$manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
Log "Device Manufacturer: $manufacturer"

# === Remove AppX + Provisioned ===
foreach ($App in $AppxToRemove) {
    try {
        $pkg = Get-AppxPackage -Name $App -ErrorAction SilentlyContinue
        if ($pkg) {
            Log "Removing AppxPackage: $App"
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
        }

        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $App }
        if ($prov) {
            Log "Removing Provisioned App: $App"
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
        }
    } catch {
        Log "Error removing Appx ${App}: $_"

    }
}

# === Remove OEM software (only for HP/Dell) ===
if ($manufacturer -match "HP|Dell") {
    foreach ($App in $OEMApps) {
        try {
            $found = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$App*" }
            foreach ($item in $found) {
                Log "Uninstalling OEM App: $($item.Name)"
                $item.Uninstall()
            }
        } catch {
            Log "Error removing Appx ${App}: $_"

        }
    }
} else {
    Log "Skipping OEM cleanup: non-HP/Dell device"
}

Log "===== Decrapify Script Completed ====="

