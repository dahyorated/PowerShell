Push-Location C:\EYdev\devops\pipelines;
$delimitedAppSettings = 'ClientID,xyzzy,false|ClientKey,xyzzy-secret,false|KeyVaultUrl,https://XXX.vault.azure.net/,false|FUNCTIONS_EXTENSION_VERSION,~2,false|Mde_Service_Api,https://YYY.ey.com/api,false|ServiceBusServiceId,mdeService,false|ServiceAuthSecretIdentifier,ServiceAuthSecret,false';
$delimitedConnectionStrings = 'Mde-ServiceBusConnectionString,mdeServiceBusConnectionString,Custom,false|Tem-ServiceBusConnectionString,temServiceBusConnectionString,Custom,false';
Set-FunctionAppSettings -DelimitedAppSettings $delimitedAppSettings -DelimitedConnectionStrings $delimitedConnectionStrings;
Pop-Location;
