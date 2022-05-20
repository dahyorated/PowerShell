<#
.Synopsis
Update the tags for all app services and app service plans in a resource group.

.Description
The Update-AppServiceTags script updates the tags for all app services and app service plans in the -ResourceGroup resource group.

.Parameter ResourceGroup
This is the resource group to be updated.

.Example
Update-AppServiceTags -ResourceGroup 'GT-WEU-GTP-CORE-DEV-RSG';

This updates the tags for all app services and app service plans in the 'GT-WEU-GTP-CORE-DEV-RSG' resoruce group.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[string]$ResourceGroup = 'GT-WEU-GTP-CORE-DEV-RSG'
)
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
[Array]$appSvcPlans = Get-AzAppServicePlan -ResourceGroupName $ResourceGroup;
Write-Output ("Found {0} app service plans in resource group '{1}'." -f $appSvcPlans.Count,$ResourceGroup);
foreach ($appSvcPlan in $appSvcPlans)
{
	Write-Output ("Processing app service plan '{0}'" -f $appSvcPlan.Name);
	$tags = $appSvcPlan.Tags;
	if (-not [string]::IsNullOrEmpty($tags.CLIENT_ID))
	{
		Write-Output ("==> {0}: {1}" -f 'CLIENT_ID',$tags.CLIENT_ID);
	}
	else
	{
		Write-Output ("==> Adding CLIENT_ID to app service plan '{0}'" -f $appSvcPlan.Name);
		$tags.CLIENT_ID = $tags.DEPLOYMENT_ID;
		Write-Output ("==> {0}: {1}" -f 'CLIENT_ID',$tags.CLIENT_ID);
		$tags.DEPLOYMENT_ID = Get-DeploymentIdFromResourceGroup -ResourceGroup $ResourceGroup;
		$appSvcPlanResourceId = $appSvcPlan.Id;
		if ($PSCmdlet.ShouldProcess("app service plan: $($appSvcPlan.Name)", "Update tags"))
		{
			Update-AzTag -ResourceId $appSvcPlanResourceId -Operation Replace -Tags $tags;
		}
	}
	Write-Output ("==> {0}: {1}" -f 'DEPLOYMENT_ID',$tags.DEPLOYMENT_ID);
	Write-Output ("==> {0}: {1}" -f 'ROLE_PURPOSE',$tags.ROLE_PURPOSE);
	Write-Output ("==> {0}: {1}" -f 'ENGAGEMENT_ID',$tags.ENGAGEMENT_ID);
	[Array]$appSvcs = Get-AzWebApp -AppServicePlan $appSvcPlan;
	Write-Output ("==> Found {0} app services." -f $appSvcs.Count);
	foreach ($appSvc in $appSvcs)
	{
		Write-Output ("====> Processing app service '{0}'" -f $appSvc.Name);
		$tags = $appSvc.Tags;
		if (-not [string]::IsNullOrEmpty($tags.CLIENT_ID))
		{
			Write-Output ("====> {0}: {1}" -f 'CLIENT_ID',$tags.CLIENT_ID);
		}
		else
		{
			Write-Output ("====> Adding CLIENT_ID to app service '{0}'" -f $appSvc.Name);
			$tags.CLIENT_ID = $tags.DEPLOYMENT_ID;
			Write-Output ("====> {0}: {1}" -f 'CLIENT_ID',$tags.CLIENT_ID);
			$tags.DEPLOYMENT_ID = Get-StageNameFromResourceGroup -ResourceGroup $ResourceGroup;
			$appSvcResourceId = $appSvc.Id;
			if ($PSCmdlet.ShouldProcess("app service: $($appSvc.Name)", "Update tags"))
			{
				Update-AzTag -ResourceId $appSvcResourceId -Operation Replace -Tags $tags;
			}
		}
		Write-Output ("====> {0}: {1}" -f 'DEPLOYMENT_ID',$tags.DEPLOYMENT_ID);
		Write-Output ("====> {0}: {1}" -f 'ROLE_PURPOSE',$tags.ROLE_PURPOSE);
		Write-Output ("====> {0}: {1}" -f 'ENGAGEMENT_ID',$tags.ENGAGEMENT_ID);	}
}
