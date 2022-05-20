Push-Location C:\EYdev\devops\scripts;
Set-DiagnosticsSettingsForEventGrid -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -EventGridTopicName "EUWDGTP005ETN01" -WorkspaceName "euwdgtp005law01" -WhatIf;
#Set-DiagnosticsSettingsForEventGrid -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -EventGridTopicName "EUWDGTP005ETN01" -WorkspaceName "euwdgtp005law01" -Verbose -WhatIf;
Pop-Location;
