Push-Location C:\EYdev\devops\scripts;
#Set-VariableGroupSets -ControlFile .\VariableGroupSetsRelease.json -WhatIf;
Set-VariableGroupSets -ControlFile .\VariableGroupSetsRelease.json;
Pop-Location;
