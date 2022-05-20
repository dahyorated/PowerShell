Push-Location "C:\eydev\devops\scripts";
try {
.\New-FailbackGTPDataSharesForExistingClients.ps1 -sendAuthServiceURL 'https://userservice-dev.sbp.eyclienthubd.com/' -sendClientServiceURL 'https://euwdgtp005wap0w.azurewebsites.net/'  `
	-sendkeyVault 'EUWDGTP005AKV01' -sendResourceGroupName 'GT-WEU-GTP-TENANT-DEV-RSG' `
	-receiveAuthServiceURL 'https://userservice-eus-dev.sbp.eyclienthub.com' -receiveClientServiceURL 'https://USEDGTP004WAP1K.azurewebsites.net'  -receivekeyVault 'USEDGTP004AKV01' `
	-receiveResourceGroupName  "GT-EUS-GTP-TENANT-DEV-RSG" -capellaClientId 136 -capellaSubscriptionId "e58114f4-8673-4cae-a138-80855cff70d9" -capellaReceiveResourceGroupName "GT-EUS-GTP-TENANT-CAPELLA-DEV-RSG" 
}
catch 
{
	Write-Output $_;
}
Pop-Location;
	
