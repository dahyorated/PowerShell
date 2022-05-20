<#
.Synopsis
Set the DMO-EUW stage to follow the STG-EUW stage in a set of release pipelines.

.Description
The Set-DmoToFollowStg script sets the DMO-EUW stage to follow the STG-EUW stage in the -QueryPath set of release pipelines.

.PARAMETER QueryPath
This is the path for the release definitions of interest.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[string]$QueryPath = "\CTP\POC\BMF 9.9",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting {0}." -f [System.IO.Path]::GetFileNameWithoutExtension($PSCmdlet.MyInvocation.InvocationName));
$conditionStageName = 'STG-EUW';
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$allRelDefs = Get-AllReleaseDefinitionsByPath -Path $QueryPath -ProjectUrl $projectUrl -AuthHeader $authHeader;
[array]$relDefs = $allRelDefs.value;
if ($relDefs.count -gt 0)
{
	$sortedRelDefs = $relDefs | Sort-Object -Property name;
	Write-Output "$($ProjectName)$($queryPath): $($relDefs.count) release definitions found";
	foreach ($relDef in $sortedRelDefs)
	{
		$relDefId = $relDef.id;
		$relDefName = $relDef.name;
		Write-Output ("==> Reviewing '{0}'." -f $relDefName);
		$isModified = $false;
		$relDefFull = Get-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $authHeader;
		[array]$dmoStage = $relDefFull.environments | Where-Object name -eq 'DMO-EUW';
		if ($dmoStage.Count -eq 0)
		{
			Write-Output ("`t==> Missing DMO-EUW stage; nothing to update." -f 0);
			continue;
		}
		[array]$dmoStageConditions = $dmoStage.conditions | Where-Object conditionType -eq "environmentState";
		$conditionCount = $dmoStageConditions.Count;
		if ($conditionCount -eq 1)
		{
			$dmoConditionStageName = $dmoStageConditions[0].name;
			if ($dmoConditionStageName -ne $conditionStageName)
			{
				Write-Output ("`t==> Prior stage was '{0}', changing to '{1}'." -f $dmoConditionStageName,$conditionStageName);
				$dmoStageConditions[0].name = $conditionStageName;
				$isModified = $true;
			}
		}
		elseif ($conditionCount -gt 1)
		{
			Write-Output ("`t==> DMO-EUW stage has {0} conditions. Please manually edit this pipeline." -f $conditionCount);
		}
		else
		{
			Write-Output "`t==> DMO-EUW stage has no conditions. Please manually edit this pipeline.";
		}
		$dmoStageApprovers =$dmoStage.preDeployApprovals;
		[array]$dmoStageApprovals = $dmoStageApprovers.approvals;
		if ($dmoStageApprovals.Count -ne 1)
		{
			Write-Output "`t==> DMO-EUW stage has no pre-deployment approvals. Please manually edit this pipeline.";
		}
		elseif ($dmoStageApprovals.Count -gt 1)
		{
			Write-Output ("`t==> DMO-EUW stage has {0} pre-deployment approvals, expected 1. Please manually edit this pipeline." -f $dmoStageApprovals.Count);
		}
		else
		{
			if ($null -ne $dmoStageApprovals[0].approver)
			{
				Write-Output "`t==> Removing approver for DMO-EUW stage.";
				$dmoStageApprovals[0].approver = $null;
				$dmoStageApprovals[0].isAutomated = $true;
				$isModified = $true;
			}
		}
		if ($isModified -and $PSCmdlet.ShouldProcess($relDefName,"Update-ReleaseDefinition"))
		{
			$relDefFull.PSObject.Properties.Remove('createdBy');
			$relDefFull.PSObject.Properties.Remove('createdOn');
			$relDefFull.PSObject.Properties.Remove('modifiedBy');
			$relDefFull.PSObject.Properties.Remove('modifiedOn');
			Write-Output ("`t==> Updating '{0}'." -f $relDefName);
			try
			{
				$updateResult =Update-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ReleaseDefinition $relDefFull -ProjectUrl $projectUrl -AuthHeader $authHeader;
				if ($null -eq $updateResult)
				{
					Write-Output "`t==> Update failed!";
				}
				else
				{
					Write-Output "`t==> Update succeeded."
				}
			}
			catch
			{
				Write-Output ("`t==> Update-ReleaseDefinitionById threw exception: {0}"-f $_.Exception.Message);
			}
		}
	}
}
Write-Output ("Finishing {0}." -f [System.IO.Path]::GetFileNameWithoutExtension($PSCmdlet.MyInvocation.InvocationName));
