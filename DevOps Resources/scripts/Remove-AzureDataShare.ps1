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

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

Write-Host "Removing Azure Data Share using '$DataShareJson'.";
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$uri = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="

if ($DataShareFullPathname.StartsWith('.') -or $DataShareFullPathname.StartsWith('.')) {
	$DataShareJson = Join-Path $PWD $DataShareFullPathname;
}
else {
	$DataShareJson = $DataShareFullPathname;
}

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
$environment = $parameters.environment;
$location = $parameters.location;
$resourceGroup = $parameters.resourceGroup;
$dataShareName = $parameters.dataShareName
$removeParam = @{
		component  = 'destroy-DataShare'
		extra_vars = @{
			var_deploy_to         = $deployTo
			var_environment       = $environment
			var_location          = $location
			var_resourceGroupName = $resourceGroup
			var_dataShareName     = $dataShareName
		}
	};
	

	$global:removeParamJson = $removeParam | ConvertTo-Json -Depth 100;
	Write-Verbose $global:removeParamJson;
	$removeClient = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $removeParamjson;	
	Write-Host $removeClient;
	$jobId = $removeClient.msg.jobid
	Write-Host "Job ID: $($jobId)";

	$global:jobStatusMsg = Wait-JobCompletion $jobId;
	Write-Verbose ($jobStatusMsg | ConvertTo-Json -Depth 100 -Compress);
