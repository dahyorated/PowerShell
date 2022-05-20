Push-Location "C:\devops\scripts";
.\New-DataSharesForGTPClient.ps1 -sendLocation 'westeurope' -clientId 78 -sendResourceGroup 'GT-WEU-GTP-TENANT-DEV-RSG' -invitationEmail 'A1232105-MSP01@EY.NET' `
	-sendAuthServiceURL 'https://userservice-dev.sbp.eyclienthubd.com/' -sendClientServiceURL 'https://euwdgtp005wap0w.azurewebsites.net/' -sendkeyVault 'EUWDGTP005AKV01' `
	-sendShareSubscriptionId '0e24abb5-5296-4edf-a4ba-d95f6fdc39d1' -sendStorageSubscriptionId '0e24abb5-5296-4edf-a4ba-d95f6fdc39d1' -DataShareFullPath "C:\file13\ads" `
	-receiveResourceGroup 'GT-EUS-GTP-TENANT-DEV-RSG'  -receiveLocation 'eastus' -receiveSubscriptionId '0e24abb5-5296-4edf-a4ba-d95f6fdc39d1' `
	-receiveAuthServiceURL 'https://userservice-eus-dev.sbp.eyclienthub.com' -receiveClientServiceURL 'https://USEDGTP004WAP1K.azurewebsites.net' -receivekeyVault 'USEDGTP004AKV01'
Pop-Location;
	
#for staging
	#make these a parameter
#$sendLocation = "westeurope";
#$clientId =   "01004";             
#$sendResourceGroup = "GT-WEU-GTP-TENANT-STG-RSG";
#$invitationEmail = "A1232105-MSP01@EY.NET"
#$regionCode = 'westeurope'
#$sendSubscriptionId = "2933b9c9-b1f2-4fd6-a201-b8e5e496bb86"
#$DataShareFullPath = "C:\file13\ADS";
#$sendAuthServiceURL = "https://userservice-stg.sbp.eyclienthub.com";
#$sendClientServiceURL = "https://EUWXGTP020WAP04.azurewebsites.net";
#$sendkeyVault = "EUWXGTP020AKV01";
#$sendShareSubscriptionId = "2933b9c9-b1f2-4fd6-a201-b8e5e496bb86";
#$sendStorageSubscriptionId = "e999aa97-90f0-4f21-b9d8-522893f76062";
#$receiveResourceGroup = "GT-EUS-GTP-TENANT-STG-RSG"
#$receiveSubscriptionId = "e999aa97-90f0-4f21-b9d8-522893f76062";
#$receiveAuthServiceURL = "https://userservice-eus-stg.sbp.eyclienthub.com";
#$receiveClientServiceURL = "https://USEXGTP021WAP3O.azurewebsites.net";
#$receiveKeyvault = "USEXGTP021AKV01";