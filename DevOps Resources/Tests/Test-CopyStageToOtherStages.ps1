Push-Location C:\EYdev\devops\pipelines;
#Copy-StageToOtherStages -PipelineName 'azurefunctions-ingest-ctp' -WhatIf;
#Copy-StageToOtherStages -PipelineName 'azurefunctions-ingest-ctp';
#Copy-StageToOtherStages.ps1 -PipelineName 'azurefunction-servicebusmessaging-ctp' -WhatIf;
#Copy-StageToOtherStages.ps1 -PipelineName 'azurefunction-servicebusmessaging-ctp';
#Copy-StageToOtherStages.ps1 -PipelineName 'notifications-db-ctp' -WhatIf;
Copy-StageToOtherStages.ps1 -PipelineName 'notifications-db-ctp';
Pop-Location;
