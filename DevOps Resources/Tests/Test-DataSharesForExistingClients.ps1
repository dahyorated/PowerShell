Push-Location "C:\eydev\devops\scripts";
try {
#dev
.\new-datasharesforexistingclients.ps1 -sendlocation 'westeurope' -sendresourcegroup 'gt-weu-gtp-tenant-dev-rsg' -invitationemail 'a1232105-msp01@ey.net' `
	-sendauthserviceurl 'https://userservice-dev.sbp.eyclienthubd.com' -sendclientserviceurl 'https://euwdgtp005wap0w.azurewebsites.net/' -sendkeyvault 'euwdgtp005akv01' `
     -DataShareFullPath "c:\file13\ads" -receiveresourcegroup 'gt-eus-gtp-tenant-dev-rsg'  -receivelocation 'eastus'  `
	-receiveauthserviceurl 'https://userservice-eus-dev.sbp.eyclienthub.com' -receiveclientserviceurl 'https://usedgtp004wap1k.azurewebsites.net' -receivekeyvault 'usedgtp004akv01' `
	-tenantid "5b973f99-77df-4beb-b27d-aa0c70b8482c" -capellaclient 136 -capellasubscriptionid "e58114f4-8673-4cae-a138-80855cff70d9" -capellasendresourcegroupname "gt-weu-gtp-tenant-capella-dev-rsg" `
	-capellareceiveresourcegroupname "gt-eus-gtp-tenant-capella-dev-rsg" -capellaspnname "ctp-codev-tax-gtp_capella_dev_tenant-app-d01" -capellaspnid "9bd0d209-801e-4c75-812b-1c417a6d98bf" `
	-capellaOmsWorkSpaceId "207ae826-d166-40be-bfd3-c6597c82c59a" -CapellaOmsWorkSpaceResourceGroup "gt-weu-gtp-tenant-capella-dev-rsg" -CapellaOmsWorkSpaceName "EUWDGTP136LAW01" 

#stage
#.\New-DataSharesForExistingClients.ps1 -sendLocation 'westeurope' -sendResourceGroup 'GT-WEU-GTP-TENANT-STG-RSG' -invitationEmail 'A1232105-MSP01@EY.NET' `
#	-sendAuthServiceURL 'https://userservice-stg.sbp.eyclienthub.com' -sendClientServiceURL 'https://EUWXGTP020WAP04.azurewebsites.net/' -sendkeyVault 'EUWXGTP020AKV01' `
#     -DataShareFullPath "C:\file13\ads" -receiveResourceGroup 'GT-EUS-GTP-TENANT-STG-RSG'  -receiveLocation 'eastus'  `
#	-receiveAuthServiceURL 'https://userservice-eus-stg.sbp.eyclienthub.com' -receiveClientServiceURL 'https://USEXGTP021WAP3O.azurewebsites.net' -receivekeyVault 'USEXGTP021AKV01' `
#	-tenantId "5b973f99-77df-4beb-b27d-aa0c70b8482c" 

	}
	catch 
	{
		Write-Output $_;
	}
Pop-Location;
	
