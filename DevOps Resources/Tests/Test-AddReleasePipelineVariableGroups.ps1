Push-Location C:\EYdev\devops\pipelines;
Add-ReleasePipelineVariableGroups -PipelineName 'notifications-db-ctp' -Set Iac -WhatIf;
Pop-Location;
