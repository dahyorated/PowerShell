Push-Location C:\EYdev\devops\pipelines;
# Set environment variable to emulate running in a pipeline.
# Variable for all branches
$ENV:RELEASE_ENVIRONMENTNAME = "QAT-EUW";
# Variables for Release 10.3
$ENV:BUILD_SOURCEBRANCHNAME = "PI10.3";
#Update-TenantReleaseDefinitionIds -WhatIf;
Update-TenantReleaseDefinitionIds;
Pop-Location;
