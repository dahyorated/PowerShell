Push-Location C:\EYdev\devops\scripts;
Import-Module .\Devops -Force;
Write-Output ("{0}==>{1}" -f 'DEV-EUW',(Get-StageNameFromResourceGroup 'GT-WEU-GTP-CORE-DEV-RSG'));
Write-Output ("{0}==>{1}" -f 'PRD-USE',(Get-StageNameFromResourceGroup 'GT-EUS-GTP-CORE-PROD-RSG'));
Pop-Location;
