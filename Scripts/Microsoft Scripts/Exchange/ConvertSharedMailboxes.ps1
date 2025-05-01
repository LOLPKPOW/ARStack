# === CONFIGURATION ===
$configPath = "C:\ARStack\Configurations\Microsoft Configurations\convert-to-shared.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$csvPath = $config.inputCsvPath
$logPath = "logs\convert-to-shared-log.csv"
$licenseSkuId = $config.licenseSkuId

# === CONNECT ===
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.Read.All"
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

# === INIT LOG ===
$logResults = @()

# === PROCESS CSV ===
Import-Csv -Path $csvPath | Where-Object { $_.EmailAddress -and $_.EmailAddress.Trim() -ne "" } | ForEach-Object {
    $email = $_.EmailAddress.Trim()
    Write-Host "\nProcessing $email..."
    $status = ""

    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction Stop
        $mailbox = Get-Mailbox -Identity $email -ErrorAction SilentlyContinue

        if ($mailbox -and $mailbox.RecipientTypeDetails -eq "SharedMailbox") {
            Write-Host "$email already shared; checking license"
            if ($user.AssignedLicenses | Where-Object { $_.SkuId -eq $licenseSkuId }) {
                Write-Host "Removing license..."
                $licenseBodyRemove = @{ addLicenses = @(); removeLicenses = @($licenseSkuId) } | ConvertTo-Json -Depth 3
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" -Body $licenseBodyRemove -ContentType "application/json"
                $status += "Removed License; "
            }
            $status += "Already Shared; "
            goto LOG
        }

        if (-not ($user.AssignedLicenses | Where-Object { $_.SkuId -eq $licenseSkuId })) {
            Write-Host "Assigning license to $email"
            $licenseBodyAdd = @{ addLicenses = @(@{ skuId = $licenseSkuId }); removeLicenses = @() } | ConvertTo-Json -Depth 3
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" -Body $licenseBodyAdd -ContentType "application/json"
            $status += "Assigned License; "
        }

        Set-Mailbox -Identity $email -Type Shared
        Start-Sleep -Seconds 30

        $mailbox = Get-Mailbox -Identity $email -ErrorAction Stop
        if ($mailbox.RecipientTypeDetails -eq "SharedMailbox") {
            $licenseBodyRemove = @{ addLicenses = @(); removeLicenses = @($licenseSkuId) } | ConvertTo-Json -Depth 3
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/assignLicense" -Body $licenseBodyRemove -ContentType "application/json"
            $status += "Converted to Shared; Removed License"
        } else {
            $status += "Conversion failed"
        }

    } catch {
        $status = "Error: $($_.Exception.Message)"
    }

    :LOG
    $logResults += [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Email     = $email
        Status    = $status
    }
}

# === EXPORT LOG ===
if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" | Out-Null }
$logResults | Export-Csv -Path $logPath -NoTypeInformation
Write-Host "\nLog saved to: $logPath"
