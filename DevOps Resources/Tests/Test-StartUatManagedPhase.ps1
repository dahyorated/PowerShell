Push-Location C:\EYdev\devops\pipelines;
#Start-UatManagedPhase -QueryPaths @('\CTP\POC\BMF 9.9') -WhatIf;
Start-UatManagedPhase -QueryPaths @('\CTP\POC\BMF 9.9');
Pop-Location;
