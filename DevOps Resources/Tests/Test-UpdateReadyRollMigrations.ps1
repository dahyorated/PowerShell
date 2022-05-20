Push-Location C:\EYdev\devops\pipelines;
Write-Output "Setting up parameters for DEV-EUW";
Import-Module -Name C:\EYdev\devops\scripts\DevOps -Force;
$kvName = Get-KeyVaultNameFromStageName -StageName $stageName;
$MigrationScript = "C:\EYdev\GTP\src\EY\GTP\Persistence\EY.GTP.Boardwalk.Database\bin\Debug\EY.GTP.Boardwalk.Database_DeployPackage.ps1";
$ServiceName = "boardwalk";
$AuthService = "https://userservice-dev.sbp.eyclienthubd.com";
$ClientService = "https://euwdgtp005wap0w.azurewebsites.net/";
$ServiceID = "provisioningservice";
#$ServiceAuthSecret = "MbQeThWmZq4t6w9z";
$ServiceAuthSecret = "NA";
Update-ReadyRollMigrations -MigrationScript $MigrationScript -ServiceName $ServiceName -AuthService $AuthService -ClientService $ClientService -ServiceID $ServiceID -ServiceAuthSecret $ServiceAuthSecret -KeyVaultName $kvName -WhatIf;
Pop-Location;