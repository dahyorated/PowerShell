Push-Location C:\EYdev\devops\scripts;
Import-Module -Name C:\EYdev\devops\scripts\DevOps -Force;
$spn = Get-SpnInfoFromStageName -StageName 'DEV-EUW' -UseCore;
$clientSecret = $spn.SpnPassword;
$clientId = $spn.SpnId;
$token = Get-AzureAdminHeader `
	-TenantId '5b973f99-77df-4beb-b27d-aa0c70b8482c' `
	-ClientId $clientId `
	-ClientSecret $clientSecret;
Write-Output ("Token:`n{0}`n" -f $token.Authorization);
Pop-Location;
