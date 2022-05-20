Push-Location C:\EYdev\devops\pipelines;
# Set environment variable to emulate running in a pipeline.
# Variable for 
$ENV:RELEASE_ENVIRONMENTNAME = "UAT-EUW";
$ENV:RELEASE_DEFINITIONID = "920";
$ENV:RELEASE_DEFINITIONNAME = "apaccit-clientconfig-db-ctp-R10.3";
#Update-TenantReleaseDefinitionId -WhatIf;
Update-TenantReleaseDefinitionId;
Pop-Location;
