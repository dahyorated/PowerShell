Push-Location "C:\devops\scripts\OneTime";
.\Create-CosmosDBForMigration.ps1 -subscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -authServiceURL "https://userservice-dev.sbp.eyclienthubd.com" -clientServiceURL "https://euwdgtp005wap0w.azurewebsites.net" -noDRAccount "euwdgtp005cdb01" -drAccount "euwdgtp005cdb02" -resourceGroupName  "GT-WEU-GTP-CORE-DEV-RSG" -kv "EUWDGTP005AKV01"
Pop-Location;
