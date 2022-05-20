Push-Location 'C:\EYdev\devops\scripts'
Import-Module -Name 'C:\EYdev\devops\scripts\DevOps' -Force;

$res = Get-ProvisioningValuesFromResourceGroup("GT-WEU-GTP-CORE-DEV-RSG");
if ($res.DeploymentId -ne "GTP005") { Write-Output "Fail"};
if ($res.AnsibleEnvironment -ne "Development") { Write-Output "Fail"};

write-output 'complete'
Pop-Location;