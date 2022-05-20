Push-Location C:\EYdev\devops\pipelines;
$files = @('6 - clientservice-ctp-R9.5.json',
'GatherScheduler-ctp-R9.5.json',
'VirusScanService-ctp-R9.5.json',
'alertservice-ctp-R9.5.json',
'apaccit-clientconfig-service-ctp-R9.5.json',
'apaccit-config-service-ctp-R9.5.json',
'boomiservice-ctp-R9.5.json',
'deliverableservice-ctp-R9.5.json',
'documentservice-ctp-R9.5.json',
'engagementservice-ctp-R9.5.json',
'entityservice-ctp-R9.5.json',
'gathertransport service-ctp-R9.5.json',
'importentityservice-ctp-R9.5.json',
'inforequest-ctp-R9.5.json',
'intgtaxfact-ctp-R9.5.json',
'mdeservice-ctp-R9.5.json',
'notificationservice-ctp-R9.5.json',
'persistenceservices-ctp-R9.5.json',
'reporting-ctp-R9.5.json',
'servicecatalog-ctp-R9.5.json',
'tfo-TaskService-api-ctp-R9.5.json',
'tfo-WorkspaceService-api-ctp-R9.5.json',
'transformationservice-ctp-R9.5.json');
Get-BuildsForReleaseBranch -Release 9.5 -Definitions $files > C:\EYdev\test\Start-Builds.ps1;
Pop-Location;