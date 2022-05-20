Push-Location C:\EYdev\devops\scripts;
Import-Module -Name C:\EYdev\devops\scripts\DevOps -Force;
$spn = Get-SpnInfoFromStageName -StageName 'DEV-EUW' -UseCore;
$clientSecret = $spn.SpnPassword;
$clientId = $spn.SpnId;
Write-Output "Testing azurefunctions-alteryx-ctp";
Set-EventGridSubscription `
	-SubscriptionId '5aeb8557-cab7-41ac-8603-9f94ad233efc' `
	-TenantId '5b973f99-77df-4beb-b27d-aa0c70b8482c' `
	-ClientId $clientId `
	-ClientSecret $clientSecret `
	-ResourceGroupName 'GT-WEU-GTP-CORE-DEV-RSG' `
	-AppName 'EUWDGTP005AFA06' `
	-FunctionName 'AlteryxServerListener_HttpTrigger' `
	-TopicName 'EWDGTP005ETN01' `
	-SubscriptionName 'euwdev-alteryx' `
	-EventType "InformationRequestStatusUpdated" `
	 -eventTTL "1440" `
	 -maxDeliveryAttempt "30" `
	 -deadLetter $true `
	 -deadLetterStorageAccount "euwdgtp005sta01" 	 
	# -Verbose;
Pop-Location;
