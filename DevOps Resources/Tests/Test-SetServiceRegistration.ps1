Push-Location C:\EYdev\devops\scripts;
$ENV:RELEASE_ENVIRONMENTNAME = 'DEV-EUW';
Set-ServiceRegistration -KeyVault EUWDGTP005AKV01 -Services @{xyzzyyservice = "XyzzyService-ServiceAuthSecret"} -VerifyOnly;
Set-ServiceRegistration -KeyVault EUWDGTP005AKV01 -Services @{xyzzyyservice = "XyzzyService-ServiceAuthSecret"} -WhatIf;
Pop-Location;
