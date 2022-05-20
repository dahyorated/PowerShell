Push-Location "C:\EYdev\devops\pipelines";
#Clone-ReleasePipeline -PipelineName '1 - user-db-ctp' -TargetPath "\CTP\POC\BMF 9.4" -Release "9.4" -Verbose;
#Clone-ReleasePipeline -PipelineName 'document-db-ctp' -TargetPath "\CTP\POC\BMF 9.9" -Release "9.9" -Verbose;
#Clone-ReleasePipeline -PipelineName 'BoardwalkService-ctp' -TargetPath "\CTP\POC\BMF 9.4" -Release 9.4 -Verbose;
#Clone-ReleasePipeline -PipelineName 'BoardwalkService-ctp' -Release 9.4 -StartBuild;
#Clone-ReleasePipeline -PipelineName 'alertservice-ctp' -TargetPath "\CTP\POC\BMF 9.9" -Release "10.1" -Verbose;
Clone-ReleasePipeline -PipelineName 'aadauthenticationservice-ctp' -TargetPath "\CTP\POC\BMF 9.9" -Release 10.5;
Clone-ReleasePipeline -PipelineName '01 - configservice-data-ctp' -TargetPath "\CTP\POC\BMF 9.9" -Release 10.5;
Pop-Location;
