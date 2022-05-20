Push-Location "C:\devops\scripts\OneTime";
.\Create-CosmosDBForMigrationForFailedClients.ps1 -subscriptionId "e45bb7e2-b46d-4f73-b12f-66c7ed1c97b7" -authServiceURL "https://userservice.sbp.eyclienthub.com" `
	-clientServiceURL "https://EUWPGTP018WAP04.azurewebsites.net" -noDRAccount "euwpgtp018cdb02" -drAccount "euwpgtp018cdb03" -resourceGroupName  "GT-WEU-GTP-CORE-PROD-RSG" `
	-kv "EUWPGTP018AKV04"
Pop-Location;
