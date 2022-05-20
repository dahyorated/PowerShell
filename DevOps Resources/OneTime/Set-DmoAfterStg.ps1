<#
.Synopisis
Set the DMO-EUW stage to follow the STG-EUW stage.

.Description
The Set-DmoAfterStg script block sets the DMO-EUW stage in the -RelDef release definition to follow the STG-EUW stage.
This script block is intended to be executed by the Set-ReleaseDefiniton script.

.Parameter RelDef
This is the full release definition.

.Outputs
This is a tuple contains three items.
- IsModified: $true if there were any changes.
- RelDef: This is the modified release definition.
- WriteOutput: This is any information that should be written to the standard output.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[PSCustomObject]$RelDef
)
$isModified = $false;
$writeOutput = @();
[array]$dmoStage = $relDefFull.environments | Where-Object name -eq 'DMO-EUW';
if ($dmoStage.Count -eq 0)
{
	$writeOutput += "Missing DMO-EUW stage; nothing to update." -f 0;
	continue;
}
[array]$dmoStageConditions = $dmoStage.conditions | Where-Object conditionType -eq "environmentState";
$conditionCount = $dmoStageConditions.Count;
if ($conditionCount -eq 1)
{
	$dmoConditionStageName = $dmoStageConditions[0].name;
	if ($dmoConditionStageName -ne $conditionStageName)
	{
		$writeOutput += "Prior stage was '{0}', changing to '{1}'." -f $dmoConditionStageName,$conditionStageName;
		$dmoStageConditions[0].name = $conditionStageName;
		$isModified = $true;
	}
}
elseif ($conditionCount -gt 1)
{
	$writeOutput += "DMO-EUW stage has {0} conditions. Please manually edit this pipeline." -f $conditionCount;
}
else
{
	$writeOutput += "DMO-EUW stage has no conditions. Please manually edit this pipeline.";
}
$dmoStageApprovers =$dmoStage.preDeployApprovals;
[array]$dmoStageApprovals = $dmoStageApprovers.approvals;
if ($dmoStageApprovals.Count -ne 1)
{
	$writeOutput += "DMO-EUW stage has no pre-deployment approvals. Please manually edit this pipeline.";
}
elseif ($dmoStageApprovals.Count -gt 1)
{
	$writeOutput += "DMO-EUW stage has {0} pre-deployment approvals, expected 1. Please manually edit this pipeline." -f $dmoStageApprovals.Count;
}
else
{
	if ($null -ne $dmoStageApprovals[0].approver)
	{
		$writeOutput += "Removing approver for DMO-EUW stage.";
		$dmoStageApprovals[0].approver = $null;
		$dmoStageApprovals[0].isAutomated = $true;
		$isModified = $true;
	}
}
return [PSCustomObject]@{
	IsModifed = $isModified;
	RelDef = $relDef;
	WriteOutput = $writeOutput;
}
