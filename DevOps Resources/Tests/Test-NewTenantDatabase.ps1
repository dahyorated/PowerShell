Push-Location 'C:\EYdev\devops\provisioning';
New-TenantDatabase.ps1 -AppSvcDbFullPathname .\BoomiInt-C00003-DEV-EUW.json -WhatIf;
#New-TenantDatabase.ps1 -AppSvcDbFullPathname .\BoomiInt-C00003-DEV-EUW.json -SkipDatabaseCreate -WhatIf;
#New-TenantDatabase.ps1 -AppSvcDbFullPathname .\BoomiInt-C00003-DEV-USE.json -WhatIf;
Pop-Location;
