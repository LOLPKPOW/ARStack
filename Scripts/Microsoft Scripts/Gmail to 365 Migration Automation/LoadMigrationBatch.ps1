# ------------------------------------------
# Load your CSV migration file (UPDATE THIS PATH)
# ------------------------------------------
$csvPath = "C:\Users\pwoodward\Desktop\Work Stuff\Migrations\APS\Migration Setup Files\OldAccountConversionBatch.csv"
$csv = [System.IO.File]::ReadAllBytes($csvPath)

# ------------------------------------------
# Create the Migration Batch (UPDATE NAME)
# ------------------------------------------
$batchName = "OldAccountConversionBatch"

New-MigrationBatch -Name $batchName `
  -SourceEndpoint "gmailEndpoint" `
  -CSVData $csv `
  -TargetDeliveryDomain "apaths.onmicrosoft.com" `
  -NotificationEmails "pwoodward@apaths.net" `
  -AutoStart:$true

Write-Host "`Migration batch '$batchName' started!"

# Replace 'OldAccountConversionBatch' if you use a different name
#Get-MigrationUser -BatchId "OldAccountConversionBatch" |
#    Get-MigrationUserStatistics |
#    Format-Table Identity, Status, PercentComplete, TotalItemsMigrated, Error -AutoSize
