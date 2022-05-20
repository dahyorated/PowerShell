[CmdletBinding()]
param (
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if (-Not (Test-Path -Path $_))
		{
			throw "File or folder does not exist";
		}; 
		return $true;
	})]
	[System.IO.FileInfo]$AppServiceJson = "AppService.json",
	[Parameter(Mandatory=$False)]
	[string]$CreateParameters = "",
	[Parameter(Mandatory=$False)]
	[string]$ServicePlanName = ""
)
# TODO: Deprecate or modify to use parameter file.
Write-Error "This needs to be modified to use parameter file.";
Exit;

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$uri = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
$jobStatusuri = "https://gtpprovisioning.sbp.eyclienthub.com/api/JobStatus?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
if ([string]::IsNullOrWhiteSpace($CreateParameters))
{
	$createparam = @{
		component  = 'create-AppService'
		extra_vars = @{
			var_deploy_to    = 'CORE'
			var_environment  = 'Development' # Development, QA, ...
			var_location     = 'westus2'
			var_deploymentId = 'GTPDOT' # DevOps Test
			as_tags          = "Import Service"
			var_inputAppServicePlanName = "<<ServicePlanName>>"
		}
	};
	if ([strong]::IsNullOrWhiteSpace($ServicePlanName))
	{
		$createparam.extra_vars.var_inputAppServicePlanName = $ServicePlanName;
	}
	$createparamjson = $createparam | ConvertTo-JSON -Depth 100
}
else
{
	$createparamjson = $CreateParameters;
}
$createclient = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $createparamjson

Write-Host $createclient
Write-Host $createclient.msg.jobid

$jobId = $createclient.msg.jobid
#$jobId = 113652
$number = 1200;
$i = 1;

do { 
    write-host "loop number $i"
    Start-Sleep 15
    $jobStatusIdparam = @{'jobid' = $jobid }
    $jobStatusIdp = $jobStatusIdparam | ConvertTo-JSON;
    Write-Host $jobStatusIdParam;
    $jobStatusResponse = Invoke-RestMethod -Uri $jobStatusuri -Method Post -ContentType "application/json"  -Body $jobStatusIdp
    $jobStatus = $jobStatusResponse.status
    $jobMsgStatus = $jobStatusResponse.msg.status
    if (($jobStatus -eq 'OK' -and $jobMsgStatus -eq 'completed') -or $jobStatus -eq 'Failed') {
        Write-Host $jobStatusResponse.msg | ConvertFrom-Json
        #Write-Host 'Resource Group: '  $jobStatusResponse.msg.resourceGroup  'SQL Server Name: '  $jobStatusResponse.msg.sqlServerName  'Key Vault Name: '  $jobStatusResponse.msg.keyVaultName  'Storage Account Name: ' $jobStatusResponse.msg.storageAccountName
        $i = 1200;
    }
    $i += 5
}
while ($i -le $number);
