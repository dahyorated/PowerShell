Push-Location C:\EYdev\devops\pipelines;
#Add-VariablesToBuildPipeline -PipelineName 'User Service - CI' -WhatIf;
Add-VariablesToBuildPipeline -PipelineName 'User Service - CI';
Add-VariablesToBuildPipeline -PipelineName 'APAC Boardwalk Service - CI' -WhatIf;
Pop-Location;
