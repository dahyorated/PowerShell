Push-Location "C:\EYdev\devops\pipelines";
Get-DeployedVersions -StageName DEV -Verbose;
Pop-Location;
