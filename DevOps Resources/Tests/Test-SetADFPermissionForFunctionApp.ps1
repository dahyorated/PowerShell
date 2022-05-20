Push-Location "C:\eydev\devops\scripts";
Set-ADFPermissionForFunctionApp.ps1 -SubscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -FunctionAppName "EUWDGTP005AFA06" -DataFactoryName "EUWDGTP005DFA02" -Verbose;
Pop-Location;
