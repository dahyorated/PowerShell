Push-Location "C:\EYdev\devops\scripts";
Write-Host "Run for start date of release" -ForegroundColor Cyan;
Set-SprintVariables -UseTest -CurrentDateTime '2020-03-02'
Write-Host "Run for start date of sprint" -ForegroundColor Cyan;
Set-SprintVariables -UseTest -CurrentDateTime '2020-02-24'
Pop-Location;
