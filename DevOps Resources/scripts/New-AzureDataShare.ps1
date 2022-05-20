<#
.SYNOPSIS
Create a new azure data share.

.DESCRIPTION
Create a new azure data share.

.PARAMETER DataShareFullPathname
This is the full pathname of a JSON file containing the parameters needed to create the app service plan and the associated app service

.PARAMETER RemoveAfterCreate
This switch removes the app service plan and the associated app service.

#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True, ValueFromPipeline = $True, HelpMessage = "JSON file containing parameters")]
	[ValidateScript( {
			if ( -Not ($_ | Test-Path) ) {
				throw "Parameter file does not exist"
			}
			return $true;
		})]
	[string]$DataShareFullPathname,
	[switch]$RemoveAfterCreate
)

Function Save-Parameters {
	param(
		[System.IO.FileInfo]$parameterFile,
		$parametersJson
	)
	Write-Verbose $parametersJson;
	$parametersJson | ConvertTo-Json -Depth 100 | Out-File -FilePath $parameterFile -Force;
}

if ($DataShareFullPathname.StartsWith('.') -or $DataShareFullPathname.StartsWith('.')) {
	$DataShareJson = Join-Path $PWD $DataShareFullPathname;
}
else {
	$DataShareJson = $DataShareFullPathname;
}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

Write-Host "Creating Azure Data Share using '$DataShareJson'.";
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$uri = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
$jobStatusuri = "https://gtpprovisioning.sbp.eyclienthub.com/api/JobStatus?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg==";
try {
	$parametersJson = Get-Content $DataShareJson | ConvertFrom-Json;
}
catch {
	Write-Host "Badly formed JSON file '$DataShareJson'."
	Write-Host $_;
	Pop-Location;
	Exit;
}
Write-Verbose $parametersJson;
$parameters = $parametersJson.parameters;
$deployTo = $parameters.deployTo
$location = $parameters.location;
$clientId = $parameters.clientId
$rolePurposeTag = "DataShare Account for client $clientId ";
$AZURE_RM_CLIENTID = $parameters.AZURE_RM_CLIENTID;
$AZURE_RM_SUB = $parameters.AZURE_RM_SUB;
$AZURE_RM_SECRET = $parameters.AZURE_RM_SECRET;
$var_omsWorkspaceName = $parameters.var_omsWorkspaceName;
$var_omsMyWorkspaceKey= $parameters.var_omsMyWorkspaceKey;
$var_omsSubscriptionId = $parameters.var_omsSubscriptionId;
$var_omsResourceGroup = $parameters.var_omsResourceGroup;
$var_azureRmSubId = $parameters.var_azureRmSubId;
$var_omsMyWorkSpaceId = $parameters.var_omsMyWorkSpaceId;
$var_azure_rm_subid = $parameters.var_azure_rm_subid;
$AZURE_RM_TENANTID = $parameters.AZURE_RM_TENANTID ;
$resourceGroup = $parameters.resourceGroup;

#ignore DeploymentId and environment from input even if supplied - and use the correct ones from the function
$provInfo = Get-ProvisioningValuesFromResourceGroup($parameters.resourceGroup);

$deploymentId = $provInfo.DeploymentId;
$environment = $provInfo.AnsibleEnvironment;


if ($parametersJson.results -eq $null) {
	#add property and skeleton object
	$results = @{
		dataShareAccount = ''
		resourceGroup    = ''
		jobId            = 0
	};
	$parametersJson | Add-Member -MemberType NoteProperty -Name results -Value $results;
	Save-Parameters $DataShareJson $parametersJson;
}
	$createParam = @{
		component  = 'create-DataShare'
		extra_vars = @{
			var_deploy_to         = $deployTo
			var_environment       = $environment
			var_location          = $location
			var_deploymentId      = $deploymentId
			var_resourceGroupName = $resourceGroup
			var_rolePurpose       = $rolePurposeTag
			AZURE_RM_CLIENTID     = $AZURE_RM_CLIENTID
            AZURE_RM_SUB          = $AZURE_RM_SUB
            var_omsWorkspaceName  = $var_omsWorkspaceName 
            var_omsMyWorkspaceKey = $var_omsMyWorkspaceKey
            AZURE_RM_SECRET       = $AZURE_RM_SECRET 
            var_omsSubscriptionId = $var_omsSubscriptionId  
            clientId              = $clientId
            var_omsResourceGroup  = $var_omsResourceGroup 
            var_azureRmSubId      = $var_azureRmSubId 
            var_omsMyWorkSpaceId  = $var_omsMyWorkSpaceId 
            var_azure_rm_subid    = $var_azure_rm_subid 
            AZURE_RM_TENANTID     = $AZURE_RM_TENANTID 
			subscription_id       = $var_azureRmSubId  
			var_tenantResourceGroupName  = $resourceGroup
		}
	};


$global:createDataShareJson = $createParam | ConvertTo-Json -Depth 100 -Compress;
Write-Verbose $global:createDataShareJson;
$global:createDataShareResponse = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $createDataShareJson;
Write-Verbose $createDataShareResponse;
$jobId = $createDataShareResponse.msg.jobid;
$parametersJson.results.jobId = $jobId;
Save-Parameters $DataShareJson $parametersJson;
try {
$global:jobStatusMsg = Wait-JobCompletion $jobId;
}
catch
{
	write-output $_
}
Write-Verbose ($jobStatusMsg | ConvertTo-Json -Depth 100 -Compress);
$DataShareName = $jobStatusMsg.var_dataShareName;
$resourceGroup = $jobStatusMsg.var_resourceGroup;
Write-Host "Data Share '$DataShareName' was created.";
$parametersJson.results.dataShareName = $DataShareName;
$parametersJson.results.resourceGroup = $resourceGroup;
Save-Parameters $DataShareJson $parametersJson;

if ($RemoveAfterCreate) {
	#	Remove-AppSvcPlan -AppServicePlanJson "$DataShareJson" -ServicePlanName $AppSvcPlanName;
}
