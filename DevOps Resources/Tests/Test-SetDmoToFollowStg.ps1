Push-Location C:\EYdev\devops\pipelines;
#..\OneTime\Set-DmoToFollowStg.ps1 -QueryPath '\CTP\POC\BMF 9.9' -WhatIf;
..\OneTime\Set-DmoToFollowStg.ps1 -QueryPath '\CTP\POC\BMF 9.9';
Pop-Location;
