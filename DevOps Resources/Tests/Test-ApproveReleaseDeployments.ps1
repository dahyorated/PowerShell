Push-Location C:\EYdev\devops\pipelines;
#Approve-ReleaseDeployments -TargetStage QAT -Filter 'R10.4' -WhatIf;
#Approve-ReleaseDeployments -TargetStage QAT -Filter 'R10.4' -DeploymentType postDeploy -WhatIf;
#Approve-ReleaseDeployments -TargetStage QAT -Filter 'R10.4' -DeploymentType postDeploy;
Approve-ReleaseDeployments -TargetStage PRD -Filter 'R10.3' -WhatIf;
Pop-Location;
