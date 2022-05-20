Push-Location C:\EYdev\devops\pipelines;
Set-ReleaseDefintion -QueryPath '\CTP\POC\BMF 9.9' -Process { C:\EYdev\devops\OneTime\Set-DmoAfterStg.ps1 -RelDef $relDefFull; } -WhatIf;
#Set-ReleaseDefintion -QueryPath '\CTP\POC\BMF 9.9' -Process { C:\EYdev\devops\OneTime\Set-DmoAfterStg.ps1 -RelDef $relDefFull; };
Pop-Location;
