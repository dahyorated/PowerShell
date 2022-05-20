Push-Location "C:\eydev\devops\scripts";
Set-KeyvaultPermissionForDataFactory.ps1 -SubscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -DataFactoryName "EUWDGTP005DFA02" -KeyVault "EUWDGTP005AKV01" -Verbose;
Pop-Location;
