Push-Location C:\EYdev\devops\pipelines;
#Add-VariablesToReleasePipeline -PipelineName 'fileingestion-db-ctp' -WhatIf; 
Add-VariablesToReleasePipeline -PipelineName 'fileingestion-db-ctp'; 
Pop-Location;
