Push-Location C:\EYdev\devops\scripts;
Import-Module -Name $PWD\DevOps -Force
$stageName = "DEV-EUW";
#$stageName = "PRD-EUW";
#$stageName = "UAT-EUW";
#$stageName = "DMO-EUW";
#$stageName = "PRD-USE";
$spn = Get-SpnInfoFromStageName -StageName $stageName;
Write-Output ("`nTenant SPN for '{0}'" -f $stageName);
Write-Output $spn.SpnName;
Write-Output $spn.SpnId;
Write-Output $spn.SpnPassword;
$spn = Get-SpnInfoFromStageName -StageName $stageName -UseCore;
Write-Output ("`nCore SPN for '{0}'" -f $stageName);
Write-Output $spn.SpnName;
Write-Output $spn.SpnId;
Write-Output $spn.SpnPassword;
Pop-Location;
