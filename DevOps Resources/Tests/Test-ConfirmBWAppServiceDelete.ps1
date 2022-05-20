Push-Location "C:\eydev\devops\scripts\OneTime"

.\Confirm-BWAppServiceDelete.ps1 -CsvFile "C:\eydev\devops\scripts\Tests\Data\AppServices_Report_ToDelete.csv" -env "prd";

Pop-Location;
