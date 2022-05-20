Push-Location "C:\eydev\devops\scripts"
.\Reset-DataSharesAfterFailback.ps1 -receiveAuthServiceURL 'https://userservice-eus-dev.sbp.eyclienthub.com'  -receiveClientServiceURL 'https://USEDGTP004WAP1K.azurewebsites.net' `
	-receivekeyVault 'USEDGTP004AKV01' 	-receiveResourceGroupName "GT-EUS-GTP-TENANT-DEV-RSG"  `
	-capellaClient 136 -capellaSubscriptionId "e58114f4-8673-4cae-a138-80855cff70d9" -capellaReceiveResourceGroupName "GT-EUS-GTP-TENANT-CAPELLA-DEV-RSG"
Pop-Location;