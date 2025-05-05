# === Load Config ===
$configPath = "C:\ARStack\Configurations\Gmail to 3665 Migration Configurations\load-migration-batch.json"
if (!(Test-Path $configPath)) {
    Write-Error "Config file not found at $configPath"
    return
}
$config = Get-Content $configPath | ConvertFrom-Json

# === Import Module and Connect ===
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -ShowBanner:$false

# === Prepare Logging and Paths ===
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir    = $config.logDir
$batchName = $config.batchName

$logFile       = Join-Path $logDir "logs\MigrationLog_$timestamp.txt"
$outputCsv     = Join-Path $logDir "output\MigrationResults_$batchName.csv"
$outputCsvBatch = Join-Path $logDir "input\MigrationBatchList.csv"
$csv           = Import-Csv -Path $config.csvPath

# Ensure log directories exist
$logFolders = @("$logDir", "$logDir\logs", "$logDir\output", "$logDir\input")
foreach ($folder in $logFolders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

# === Start Logging ===
"[$(Get-Date)] Starting migration batch '$batchName'" | Out-File -FilePath $logFile

# === Create Migration Batch ===
try {
    if (-not (Get-MigrationBatch -Identity $batchName -ErrorAction SilentlyContinue)) {
        $csvData = $csv | ForEach-Object {
            New-Object PSObject -property @{
                SourceEmail = $_.SourceEmail
                TargetEmail = $_.TargetEmail
            }
        }
        New-MigrationBatch -Name $batchName `
            -SourceEndpoint $config.sourceEndpoint `
            -CSVData $csvData `
            -NotificationEmails $config.notificationEmails `
            -AutoStart:$true

        "[$(Get-Date)] Migration batch '$batchName' created and started." | Out-File -FilePath $logFile -Append
    } else {
        "[$(Get-Date)] Batch '$batchName' already exists. Skipping creation." | Out-File -FilePath $logFile -Append
    }
} catch {
    "[$(Get-Date)] ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
    return
}

# === Export Batch Results ===
Start-Sleep -Seconds 10

try {
    Get-MigrationUser -BatchId $batchName |
        Get-MigrationUserStatistics |
        Select-Object Identity, Status, PercentComplete, TotalItemsMigrated, LastSuccessfulSyncTime |
        Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8

    "[$(Get-Date)] Migration results saved to: $outputCsv" | Out-File -FilePath $logFile -Append
} catch {
    "[$(Get-Date)] Failed to export results: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
}

# === Append to DeltaSync Batch List ===
if (-not (Test-Path $outputCsvBatch)) {
    @{ BatchName = $batchName } | Export-Csv -Path $outputCsvBatch -NoTypeInformation -Encoding UTF8
} elseif (-not (Import-Csv $outputCsvBatch | Where-Object { $_.BatchName -eq $batchName })) {
    @{ BatchName = $batchName } | Export-Csv -Path $outputCsvBatch -NoTypeInformation -Encoding UTF8 -Append
}
