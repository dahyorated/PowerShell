Push-Location "C:\devops\scripts\OneTime";
.\Create-CosmosDBForMigrationCapella.ps1 -subscriptionId "0a996f5c-c75e-4adf-844a-60a6fdde8cd6" -authServiceURL "https://userservice-uat.sbp.eyclienthubd.com" `
		-clientServiceURL "https://EUWUGTP014WAP0T.azurewebsites.net" -drAccount "euwugtp019cdb03" `
		-resourceGroupName  "GT-WEU-GTP-TENANT-CAPELLA-UAT-RSG" -kv "EUWUGTP014AKV01" -capellaClient 19 -installModule $false
Pop-Location;
