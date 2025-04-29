Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline
# ------------------------------------------
# CONFIGURATION
# ------------------------------------------
$batchName = "Active User Catchup"  ## Change this per batch
$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Migration Setup Files\activeusercatchup.csv"
$logDir = "C:\AutomationLogs"

# ------------------------------------------
# PREP DIRECTORIES AND PATHS
# ------------------------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "logs\MigrationLog_$timestamp.txt"
$outputCsv = Join-Path $logDir "output\MigrationResults_$batchName.csv"
$outPutCsvBatch = Join-Path $logDir "input\MigrationBatchList.csv"
$csv = [System.IO.File]::ReadAllBytes($csvPath)

$logFolders = @("$logDir", "$logDir\logs", "$logDir\output")
foreach ($folder in $logFolders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

# ------------------------------------------
# LOG START
# ------------------------------------------
"[$(Get-Date)] Starting migration batch '$batchName'" | Out-File -FilePath $logFile

# ------------------------------------------
# CREATE MIGRATION BATCH
# ------------------------------------------
try {
    if (-not (Get-MigrationBatch -Identity $batchName -ErrorAction SilentlyContinue)) {
        New-MigrationBatch -Name $batchName `
            -SourceEndpoint "gmailEndpoint" `
            -CSVData $csv `
            -TargetDeliveryDomain "apaths.onmicrosoft.com" `
            -NotificationEmails "pwoodward@apaths.net" `
            -AutoStart:$true

        "[$(Get-Date)] Migration batch '$batchName' created and started." | Out-File -FilePath $logFile -Append
    } else {
        "[$(Get-Date)] Batch '$batchName' already exists. Skipping creation." | Out-File -FilePath $logFile -Append
    }
}
catch {
    "[$(Get-Date)] ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
    return
}

# ------------------------------------------
# EXPORT MIGRATION STATUS
# ------------------------------------------
Start-Sleep -Seconds 10  # Let some status populate

try {
    Get-MigrationUser -BatchId $batchName |
        Get-MigrationUserStatistics |
        Select-Object Identity, Status, PercentComplete, TotalItemsMigrated, LastSuccessfulSyncTime |
        Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8

    "[$(Get-Date)] Migration results saved to: $outputCsv" | Out-File -FilePath $logFile -Append
}
catch {
    "[$(Get-Date)] Failed to export results: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
}
# ------------------------------------------
# EXPORT BATCH NAMES TO LOAD WITH DELTASYNC.PS!
# ------------------------------------------
if (-not (Test-Path $outputCsvBatch)) {
  @{ BatchName = $batchName } | Export-Csv -Path $outputCsvBatch -NoTypeInformation -Encoding UTF8
}
elseif (-not (Import-Csv $outputCsvBatch | Where-Object { $_.BatchName -eq $batchName })) {
  @{ BatchName = $batchName } | Export-Csv -Path $outputCsvBatch -NoTypeInformation -Encoding UTF8 -Append
}