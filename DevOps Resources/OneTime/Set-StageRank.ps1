<#
.Synopisis
Set the rank of the stages to the standard ordering to facilitate UI display.

.Description
The Set-StageRank script block sets the rank of the stages in the -RelDef release definition to the standard ordering.
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
#
$rank =0;
$stageSequence = @('DEV-EUW','QAT-EUW','UAT-EUW','PRF-EUW','STG-EUW','DMO-EUW','PRD-EUW','DEV-USE','STG-USE','PRD-USE');
foreach ($stage in $stageSequence)
{
	[array]$relStage = $RelDef.environments | Where-Object name -eq $stage;
	if ($relStage.Count -eq 1)
	{
		$rank++;
		if ($relStage[0].rank -ne $rank)
		{
			$writeOutput += "{0}: Changed rank from {1} to {2}." -f $stage,$relStage[0].rank,$rank;
			$relStage[0].rank = $rank;
			$isModified = $true;
		}
	}
}
#
return [PSCustomObject]@{
	IsModifed = $isModified;
	RelDef = $relDef;
	WriteOutput = $writeOutput;
}
