Import-Module ExchangeOnlineManagement

# Path to your batch list CSV
$csvPath = "C:\AutomationLogs\input\MigrationBatchList.csv"

# Load the CSV
$batches = Import-Csv -Path $csvPath

# Loop through each batch name and start it
foreach ($batch in $batches) {
    try {
        Write-Host "Starting migration batch: $($batch.BatchName)" -ForegroundColor Cyan
        Start-MigrationBatch -Identity $batch.BatchName
    }
    catch {
        Write-Host "Failed to start batch $($batch.BatchName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
