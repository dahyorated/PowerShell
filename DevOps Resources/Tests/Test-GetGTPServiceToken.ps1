Push-Location C:\EYdev\devops\pipelines;
$stageName = "DEV-EUW";
Import-Module -Name C:\EYdev\devops\scripts\DevOps -Force;
$kvName = Get-KeyVaultNameFromStageName -StageName $stageName;
$token = Get-GTPServiceToken -KeyVault $kvName -AuthService https://userservice-dev.sbp.eyclienthubd.com;
Write-Output ("Token for {0}: {1}" -f $stageName,$token);
Pop-Location;
