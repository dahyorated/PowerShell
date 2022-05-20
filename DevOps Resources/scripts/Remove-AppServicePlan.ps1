[CmdletBinding()]
param (
	[Parameter(Mandatory=$True)]
	[System.IO.FileInfo]$AppSvcPlanJson,
	[Parameter(Mandatory=$True)]
	[string]$ServicePlanName,
	[Parameter(Mandatory=$False)]
	[string]$StageName = "euwdev",
	[switch]$NoUpdate,
	[switch]$Force
)
if (-not $Force)
{
	$response = Read-Host -Prompt "Do you really want to remove this app service plan? [y/N]";
	if (-not ($response -like "y*"))
	{
		Exit;
	}
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$uri = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
$jobStatusuri = "https://gtpprovisioning.sbp.eyclienthub.com/api/JobStatus?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
$parametersJson = Get-Content $AppSvcPlanJson | ConvertFrom-Json;
$parameters = $parametersJson.parameters;
$environment = $parameters.environment;
$location = $parameters.location;
$deploymentId = $parameters.deploymentId;
$serviceName = $parameters.serviceName;
Write-Host "Removing app service plan for '$($serviceName)'.";
$removeParam = @{
component = "destroy-AppServicePlan"
	extra_vars = @{
		var_deploy_to = "CORE"
		var_environment = $environment
		var_location = $location
		var_deploymentId = $deploymentId
		var_numberOfWorkers = 1
		var_applicationServicePlanOS = "windows"
		var_appSNames = @($serviceName)
		var_rolePurposeTags = "App Service Plan for $($serviceName)"
		sku_code = "P1V2"
		var_appServicePlanName = $ServicePlanName
	}
};
$global:removeParamJson = $removeParam | ConvertTo-Json -Depth 100;
Write-Verbose $global:removeParamJson;
$removeClient = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $removeParamjson;

Write-Host $removeClient;
$jobId = $removeClient.msg.jobid
Write-Host "Job ID: $($jobId)";

$jobStatusBodyJsonParam =   @{'jobid' = $jobid};
$jobStatusBodyJson = $jobStatusBodyJsonParam  | ConvertTo-Json -Depth 100 -Compress;
$number=1200;
$i = 1;
do{ 
	write-host "Loop number $i";
	Start-Sleep 15;
	$global:removeJobResponse = Invoke-RestMethod -Uri $jobStatusuri -Method Post -ContentType "application/json"  -Body $jobStatusBodyJson;
	$jobMsg = $removeJobResponse.msg;
	$jobStatus = $jobMsg.status;
	if ($jobStatus -eq 'completed' -or $jobStatus -eq 'Failed')
	{
		Write-Host $jobMsg  | ConvertTo-Json -Depth 100 -Compress;
		$i = 1200;
	}
	$i += 5;
}
while ($i -le $number);
