Push-Location "C:\EYdev\devops\pipelines";
Clone-ReleasePipeline -PipelineName '2 - userservice-ctp' -TargetPath "\CTP\POC\BMF 9.4" -Release "9.4";
Clone-ReleasePipeline -PipelineName 'BoardwalkService-ctp' -TargetPath "\CTP\POC\BMF 9.4" -Release 9.4;
Read-Host "Review and then press Enter";
Start-UatPhase -QueryPaths @('\CTP\POC\BMF 9.4');
Read-Host "Review and then press Enter";
Start-StgPhase -QueryPaths @('\CTP\POC\BMF 9.4');
Pop-Location;
