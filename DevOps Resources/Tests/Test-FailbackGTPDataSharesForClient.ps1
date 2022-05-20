Push-Location "C:\eydev\devops\scripts";
.\New-FailbackGTPDataSharesForClient.ps1 -subscriptionId "054f8541-b074-439e-94b5-3951f19ac8d2" -receiveResourceGroupName  "GT-EUS-GTP-TENANT-DEV-RSG" `
	-receiveDataShareAccountName  "UE2DGTP005ADS01" -origReceiveShareName "DRReceiveShare" -newReceiveShareName "DRFailbackSend" -receiveStorageAccountName "usedgtp401sta01" `
	-TargetEmail  "A1232105-MSP01@EY.NET" -intClientID  401 -sendResourceGroupName "GT-WEU-GTP-TENANT-DEV-RSG" -sendDataShareAccountName  "EUWDGTP005ADS0D" `
	-sendShareName  "DRFailbackReceive" -sendstorageAccountName "euwdgtp401sta01"

Pop-Location;
	
