Push-Location C:\EYdev\devops\pipelines;
Validate-BuildDefinition -PipelineName 'Notification API - CI';
Validate-BuildDefinition -PipelineName 'Client Service - CI';
Validate-BuildDefinition -PipelineName 'Client Service - CI'
Validate-BuildDefinition -PipelineName 'Task Service - CI';
Validate-BuildDefinition -PipelineName 'Test CI';
Validate-BuildDefinition -PipelineName 'APAC CIT Boardwalk Database - CI';
Pop-Location;
