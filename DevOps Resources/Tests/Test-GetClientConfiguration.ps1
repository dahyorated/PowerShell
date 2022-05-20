Push-Location C:\EYdev\devops\pipelines;
$stageName = "DEV-EUW";
Import-Module -Name C:\EYdev\devops\scripts\DevOps -Force;
$kvName = Get-KeyVaultNameFromStageName -StageName $stageName;
$clientConfigs = Get-ClientConfiguration -KeyVault $kvName `
	-AuthService https://userservice-dev.sbp.eyclienthubd.com `
	-ClientService https://euwdgtp005wap0w.azurewebsites.net/;
Write-Output ("Client configurations for {0}:" -f $stageName);
foreach ($clientConfig in $clientConfigs)
{
	Write-Output $clientConfig;
}
Pop-Location;
