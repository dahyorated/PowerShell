<#
.SYNOPSIS
Clone all requested pipelines.

.DESCRIPTION
The Clone-AllReleasePipelines.ps1 script clones all requested pipelines.

.PARAMETER Release
This is the current release and must be in the form "9.9".

.EXAMPLE
Clone-RequirePipelines -Release '9.1'

This clones all requested pipelines into the '\CTP\Release 9.1' folder.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True)]
	[string]$Release
)
$targetPath = "\CTP\Release {0}" -f $Release;
# TODO Get list from 'TenantDatabasesToClone.json' and add '5 - client-db-ctp'.
$rdToClone = @(
	'1 - user-db-ctp',
	'2 - userservice-ctp',
	'4 - eurekaservice-ctp',
	'5 - client-db-ctp',
	'6 - clientservice-ctp',
	'alertservice-ctp',
	'alertservice-db-ctp',
	'apaccit-boardwalk-db-ctp',
	'apaccit-clientconfig-db-ctp',
	'apaccit-clientconfig-service-ctp',
	'apaccit-config-db-ctp',
	'apaccit-config-service-ctp',
	'APIM Release-ctp',
	'azurefunction-apaccit-alteryx-workflow-ctp',
	'azurefunction-apimkeyrotation-ctp',
	'azurefunction-boardwalk-ctp',
	'azurefunction-gatherscheduler-ctp',
	'azurefunctions-alteryx-ctp',
	'azurefunction-servicebusmessaging-ctp',
	'azurefunctions-gather-ctp',
	'azurefunctions-ingest-ctp',
	'azurefunctions-notification-ctp',
	'azurefunctions-pushnotification-ctp',
	'boardwalk-db-ctp',
	'boomiservice-ctp',
	'datawarehouse-adf-ctp',
	'deliverableservice-ctp',
	'demoservice-api-ctp',
	'designsystem-CTP',
	'document-db-ctp',
	'documentservice-ctp',
	'emailservice-ctp',
	'engagementservice-ctp',
	'entityservice-ctp',
	'entityservice-db-ctp',
	'fileingestion-db-ctp',
	'GatherScheduler-ctp',
	'gatherscheduler-db-ctp',
	'gathertransport service-ctp',
	'Global Tax Platform - App - APIM - Future-Portal (ctp)',
	'Global Tax Platform - App - APIM - Portal (ctp)',
	'importentityservice-ctp',
	'inforequest-ctp',
	'inforequest-db-ctp',
	'ingestioneygtpods-db-ctp',
	'ingestionwebjob-ctp',
	'intgtaxfact-ctp',
	'logging-db-ctp',
	'mdeservice-ctp',
	'mdeservice-db-ctp',
	'notifications-db-ctp',
	'notificationservice-ctp',
	'payment-tracker-api-ctp',
	'persistenceservices-ctp',
	'reportcatalog-db-ctp',
	'reporting-ctp',
	'reporting-db-ctp',
	'servicecatalog-ctp',
	'servicecatalog-db-ctp',
	'taxfactei-db-ctp',
	'tfo-db-ctp',
	'tfo-TaskService-api-ctp',
	'tfo-tracker-api-ctp',
	'tfo-tracker-webui-ctp',
	'tfo-WorkspaceService-api-ctp',
	'transformation-db-ctp',
	'transformationservice-ctp',
	'Trial Balance (Tax Fact) Service-ctp',
	'VirusScanService-ctp'
);
$rdToClone | ForEach-Object {
	Clone-ReleasePipeline -PipelineName $_ -Release $Release -TargetPath $targetPath;
};
