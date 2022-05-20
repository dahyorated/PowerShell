<#
.SYNOPSIS
Create a new app service plan and an associated app service.

.DESCRIPTION
Create a new app service plan and an associated app service.

.PARAMETER AppSvcPlanFullPathname
This is the full pathname of a JSON file containing the parameters needed to create the app service plan and the associated app service

.PARAMETER SkuCode
This is the Azure SKU code for the size of the VM to be used for the app service plan.
This parameter's value is used if it is not specified in the -AppSvcPlanFullPathname JSON file (value of "skuCode").

.PARAMETER RemoveAfterCreate
This switch removes the app service plan and the associated app service.

.PARAMETER PlanOnly
This switch skips the create of the app service. Only the app service plan is created.

.PARAMETER AppSvcOnly
This switch skips the creation of the app service plan, but still creates the app service using the content of the -AppSvcPlanFullPathname JSON file.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param (
	[Parameter(Mandatory=$True,ValueFromPipeline=$True,HelpMessage="JSON file containing parameters")]
	[ValidateScript({
		if( -Not ($_ | Test-Path) )
		{
			throw "Parameter file does not exist"
		}
		return $true;
	})]
	[string]$AppSvcPlanFullPathname,
	[Parameter(Mandatory=$true)]
	[ValidatePattern('(DEV|QAT|UAT|DMO|PRF|STG|PRD)-(EUW|USE)')]
	[string]$StageName,
	[Parameter(Mandatory=$False)]
	[string]$SkuCode = "P1V2",
	[switch]$RemoveAfterCreate,
	[switch]$PlanOnly,
	[switch]$AppSvcOnly
)

Function Save-ParametersToFile
{
	param(
		[System.IO.FileInfo]$parameterFile,
		$parametersJson
	)
	Write-Verbose $parametersJson;
	$parametersJson | ConvertTo-Json -Depth 100 | Out-File -FilePath $parameterFile -Force;
}

Function Get-SubscriptionFromStageName
{
	param(
		[string]$StageName
	)
	$subName = switch -Regex ($StageName)
	{
		"DMO-*" {'EY-CTSBP-PROD-TAX-GTP_DEMO_CORE-01-39861197'}
		"(STG|PRD)-*" {'EY-CTSBP-PROD-TAX-GTP CORE-01-39721502'}
		default {'EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502'}
	}
	$subscription = Get-AzSubscription -SubscriptionName $subName;
	return $subscription;
}

if ($AppSvcPlanFullPathname.StartsWith('.') -or $AppSvcPlanFullPathname.StartsWith('.'))
{
	$AppSvcPlanJson = Join-Path $PWD $AppSvcPlanFullPathname;
}
else
{
	$AppSvcPlanJson = $AppSvcPlanFullPathname;
}
Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
$initialContext = Get-AzContext;
Write-Output "Creating AppSvc Plan using '$AppSvcPlanJson'.";
$targetSubscription = Get-SubscriptionFromStageName -StageName $StageName;
Set-AzContext -SubscriptionId $targetSubscription;
# TODO: Should Get-SpnInfoFromStageName include -UseCore?
$useCore = $false;
#$useCore = $StageName.StartsWith('PRF');
$spn = Get-SpnInfoFromStageName -StageName $StageName -UseCore:$useCore;
$uri = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg==";
try
{
	$parametersJson = Get-Content $AppSvcPlanJson | ConvertFrom-Json;
}
catch
{
	Write-Output "Badly formed JSON file '$AppSvcPlanJson'."
	Write-Output $_;
	Pop-Location;
	Exit;
}
Write-Verbose $parametersJson;
$parameters = $parametersJson.parameters;
$environment = $parameters.environment;
$location = $parameters.location;
$deploymentId = $parameters.deploymentId;
$serviceName = $parameters.serviceName;
$skuCode = $parameters.skuCode;
$resourceGroup = $parameters.resourceGroup;
if ([string]::IsNullOrWhiteSpace($skuCode))
{
	$skuCode = $SkuCode;
}
if ($null -eq $parametersJson.results)
{
	#add property and skeleton object
	$results = @{
		appSvcPlan = ''
		appSvc = ''
		resourceGroup = ''
		appInsights = ''
		appSvcPlanJob = 0
		appSvcJob = 0
	};
	$parametersJson | Add-Member -MemberType NoteProperty -Name results -Value $results;
	Save-ParametersToFile $AppSvcPlanJson $parametersJson;
}
if ([string]::IsNullOrWhiteSpace($resourceGroup))
{
	$createParam = @{
		component = 'create-AppServicePlan'
		extra_vars = @{
			var_deploy_to = 'CORE'
			var_environment = $environment
			var_location = $location
			var_deploymentId = $deploymentId
			asp_names = $serviceName
			asp_os = 'windows'
			asp_tags = "App Service Plan for $($serviceName)"
			number_workers = 1
			sku_code = $skuCode
		}
	};
}
else
{
	$createParam = @{
		component = 'create-AppServicePlan'
		extra_vars = @{
			var_deploy_to = 'CORE'
			var_environment = $environment
			var_location = $location
			var_deploymentId = $deploymentId
			asp_names = $serviceName
			asp_os = 'windows'
			asp_tags = "App Service Plan for $($serviceName)"
			number_workers = 1
			sku_code = $skuCode
			var_resourceGroupName = $resourceGroup
		}
	};
}
$global:createAppSvcPlanJson = $createParam | ConvertTo-Json -Depth 100 -Compress;
Write-Verbose $global:createAppSvcPlanJson;
if ($AppSvcOnly)
{
	$AppSvcPlanName = $parametersJson.results.appSvcPlan;
	$resourceGroup = $parametersJson.results.resourceGroup;
}
elseif ($PSCmdlet.ShouldProcess($serviceName,"Create App Service Plan"))
{
	$global:createAppSvcPlanResponse = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $createAppSvcPlanJson;
	Write-Verbose $createAppSvcPlanResponse;
	$jobId = $createAppSvcPlanResponse.msg.jobid;
	$parametersJson.results.appSvcPlanJob = $jobId;
	Save-ParametersToFile $AppSvcPlanJson $parametersJson;
	$global:jobStatusAppSvcPlanMsg = Wait-JobCompletion $jobId;
	Write-Verbose ($jobStatusAppSvcPlanMsg | ConvertTo-Json -Depth 100 -Compress);
	$AppSvcPlanName =$jobStatusAppSvcPlanMsg.var_appServicePlanName;
	# var_appServicePlanName contains extraneous characters: " [u'xxx']"
	$AppSvcPlanName = [regex]::Match($AppSvcPlanName.ToUpper(),'[A-Z0-9]{2,}').Value;
	$resourceGroup = $jobStatusAppSvcPlanMsg.var_resourceGroup;
	Write-Output "App Service Plan '$AppSvcPlanName' was created.";
	$parametersJson.results.appSvcPlan = $AppSvcPlanName;
	$parametersJson.results.resourceGroup = $resourceGroup;
	Save-ParametersToFile $AppSvcPlanJson $parametersJson;
}
if (-not $PlanOnly)
{
	$laws = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroup;
	$law = $laws | Where-Object {$_.Tags.LOGGING_GROUP -eq 'General Core'};
	$lawName = $law.Name;
	$workspaceId = $law.CustomerId;
	$lawKey = $law | Get-AzOperationalInsightsWorkspaceSharedKey;
	$lawParts = $law.ResourceId.Split('/',[StringSplitOptions]::RemoveEmptyEntries);
	$subscriptionId = $lawParts[1];
	$tenantId = (Get-AzContext).Tenant.Id;
	if ([string]::IsNullOrWhiteSpace($resourceGroup))
	{
		$createParam = @{
			component = 'create-AppService'
			extra_vars = @{
				var_deploy_to = 'CORE'
				var_environment = $environment
				var_location = $location
				var_deploymentId = $deploymentId
				as_tags = "App Service for $($serviceName)"
				var_inputAppServicePlanName = "$AppSvcPlanName"
			}
		};
	}
	else
	{
		$createParam = @{
			component = 'create-AppService'
			extra_vars = @{
				var_deploy_to = 'CORE';
				var_environment = $environment;
				var_location = $location;
				var_deploymentId = $deploymentId;
				as_tags = "App Service for $($serviceName)";
				var_inputAppServicePlanName = "$AppSvcPlanName";
				var_resourceGroupName = $resourceGroup;
				AZURE_RM_CLIENTID = $spn.SpnId;
				AZURE_RM_SECRET = $spn.SpnPassword;
				AZURE_RM_TENANTID = $tenantId;
				var_azureRmSubId = $subscriptionId;
				var_omsMyWorkSpaceId = $workspaceId;
				var_omsMyWorkspaceKey = $lawKey.PrimarySharedKey;
				var_omsResourceGroup = $resourceGroup; # Log Analytics RSG
				var_omsSubscriptionId = $subscriptionId;
				var_omsWorkspaceName = $lawName;
			}
		};
	}
	$global:createAppSvcJson = $createParam | ConvertTo-Json -Depth 100 -Compress;
	Write-Verbose $global:createAppSvcJson;
	if ($PSCmdlet.ShouldProcess($serviceName,"Create App Service"))
	{
		$global:createAppSvcResponse = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $createAppSvcJson;
		Write-Verbose $createAppSvcResponse;
		$jobId = $createAppSvcResponse.msg.jobid;
		$parametersJson.results.appSvcJob = $jobId;
		Save-ParametersToFile $AppSvcPlanJson $parametersJson;
		$global:jobStatusAppSvcMsg = Wait-JobCompletion $jobId -noExit;
		Write-Verbose ($jobStatusAppSvcMsg | ConvertTo-Json -Depth 100 -Compress);
		if (-not [string]::IsNullOrWhiteSpace($jobStatusAppSvcMsg.Status) -and ($jobStatusAppSvcMsg.Status -ne 'completed'))
		{
			$parametersJson | Add-Member -MemberType NoteProperty -Name error -Value $jobStatusAppSvcMsg;
			Save-ParametersToFile $AppSvcPlanJson $parametersJson;
			Exit;
		}
		$appSvcName = $jobStatusAppSvcMsg.var_webAppName;
		$appInsightsName = $jobStatusAppSvcMsg.var_AppInsightsName;
		$parametersJson.results.appSvc = $appSvcName;
		$parametersJson.results.appInsights = $appInsightsName;
		$parametersJson.results.resourceGroup = $jobStatusAppSvcPlanMsg.var_resourceGroup;
		Write-Output "App Service '$($appSvcName[0])' for '$serviceName' was created.";
		Write-Output "AppInsights Name: '$appInsightsName'."
	}
}
Save-ParametersToFile $AppSvcPlanJson $parametersJson;
if ($RemoveAfterCreate)
{
	Remove-AppSvcPlan -AppServicePlanJson "$AppSvcPlanJson" -ServicePlanName $AppSvcPlanName;
}
Set-AzContext -Context $initialContext;
