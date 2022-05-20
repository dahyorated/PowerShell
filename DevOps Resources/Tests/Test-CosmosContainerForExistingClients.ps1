Push-Location "C:\eydev\devops\scripts";
.\New-CosmosContainerForExistingClients.ps1 -subscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -authServiceURL "https://userservice-dev.sbp.eyclienthubd.com" -clientServiceURL "https://EUWDGTP005WAP0W.azurewebsites.net" `
		-drAccount "euwdgtp005cdb02"  -noDRAccount "euwdgtp005cdb02" -resourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -kv "EUWDGTP005AKV01" -serviceName "widgetservice" -partionKey "/partitionKey" `
		-capellaClient 136 -capellaSubscriptionId "e58114f4-8673-4cae-a138-80855cff70d9" -capellaCosmosAccount "euwdgtp136cdb03" -capellaResourceGroupName "GT-WEU-GTP-TENANT-CAPELLA-DEV-RSG" -loadModule $false



Pop-Location;

