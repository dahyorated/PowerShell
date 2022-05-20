Write-output "hello"
Push-Location "C:\EYdev\devops\scripts";

 .\Set-WorkspaceIdToKeyvault.ps1 -kv "EUWDGTP005AKV01" -resourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -appInsightsName "EUWDGTP001AIN01";
Pop-Location