Push-Location "C:\devops\scripts";
.\New-ServiceBusQueue.ps1 -kv "EUWDGTP005AKV01" -nameSpace "EUWDGTP005SBS01" -resourceGroup "GT-WEU-GTP-CORE-DEV-RSG" -queueName "DanTest1" 
	Pop-Location;
