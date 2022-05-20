Push-Location C:\EYdev\devops\pipelines;
$AuthService = "https://userservice-dev.sbp.eyclienthubd.com";
$ClientService = "https://EUWDGTP005WAP0W.azurewebsites.net";
$WarFile = "$PWD/_BoardwalkTest/GtpWarFile/ROOT.war";
$KeyVault = "EUWDGTP005AKV01";
$ServiceID = 'provisioningservice';
$SubscriptionId = "5aeb8557-cab7-41ac-8603-9f94ad233efc";
$secretName = $ServiceID + "-ServiceAuthSecret";
$ServiceAuthSecret = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name $secretName).SecretValueText;

Deploy-BoardWalkForEnvironment `
	-CoreVaultName $KeyVault `
	-SubscriptionIdCore $SubscriptionId `
	-ResourceGroupNameCore 'GT-WEU-GTP-CORE-DEV-RSG' `
	-AuthService $AuthService `
	-ClientService $ClientService `
	-ServiceID $ServiceID `
	-ServiceAuthSecret $ServiceAuthSecret `
	-WarFile $WarFile `
	-AzureGTPvalidateEP "$AuthService/api/v1/session" `
	-AzureServiceTokenURLName "$AuthService/api/v1/authenticate/login" `
	-AzureTaxFactDataServiceBaseURLName "https://euwdgtp005wap0t.azurewebsites.net" `
	-Boardwalksmtpserver "gtpwebmail.westeurope.cloudapp.azure.com" `
	-AzureLoginURL 'https://gtp-dev.ey.com/login' `
	-BwServiceName 'boardwalk' `
	-SpecificClientId '' `
	-BuildNumber '10.7.0.1' `
	-IsPrimarySite $true `
;
Pop-Location;
