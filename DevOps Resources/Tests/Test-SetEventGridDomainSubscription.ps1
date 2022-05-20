Push-Location C:\EYdev\devops\scripts;
Import-Module -Name C:\EYdev\devops\scripts\DevOps -Force;
$spn = Get-SpnInfoFromStageName -StageName 'DEV-EUW' -UseCore;
$clientSecret = $spn.SpnPassword;
$clientId = $spn.SpnId;
Set-EventGridDomainSubscription `
	-SubscriptionId '5aeb8557-cab7-41ac-8603-9f94ad233efc' `
	-TenantId '5b973f99-77df-4beb-b27d-aa0c70b8482c' `
	-ClientId $clientId `
	-ClientSecret $clientSecret `
	-ResourceGroupName 'GT-WEU-GTP-CORE-DEV-RSG' `
	-AppName 'EUWDGTP005AZF0M' `
	-FunctionName 'DWNotification' `
	-TopicName 'dwnotification-topic' `
	-DomainName 'EUWDGTP005AED01' `
	-SubscriptionName 'dwnotification-subscription' `
	-EventType "DWADFStatusCompleted:DW​ADFStatusError" -Verbose -WhatIf;
Pop-Location;
