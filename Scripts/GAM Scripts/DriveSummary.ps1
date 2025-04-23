$csvPath = "C:\GAMADV-XTD3\StaleAccounts.csv"
$outputPath = "C:\GAMADV-XTD3\DriveSizeSummary.csv"
$gam = "C:\GAMADV-XTD3\gam.exe"

# Header
"Email,FileCount,TotalSizeBytes" | Out-File -FilePath $outputPath -Encoding UTF8

Import-Csv $csvPath | ForEach-Object {
    $email = $_.Email
    Write-Host "Scanning $email..."

    $fileCount = 0
    $sizeSum = 0

    try {
        $result = & $gam user $email show filelist fields id,title,size 2>&1

        # Filter only valid data lines
        $dataLines = $result | Where-Object { $_ -match '^[^,]+,[^,]+,[^,]+,\d+$' }

        $fileCount = $dataLines.Count

        foreach ($line in $dataLines) {
            $columns = $line -split ','
            if ($columns.Count -eq 4) {
                try {
                    $size = [int64]$columns[3]
                    $sizeSum += $size
                } catch {
                    Write-Host "Couldn't convert size from: $line"
                }
            }
        }
    } catch {
        Write-Host "Query failed for $email."
    }

    # Always log result line
    "$email,$fileCount,$sizeSum" | Out-File -Append -FilePath $outputPath -Encoding UTF8
}
