<#
.Synopisis
Set the DMO-EUW stage to the DevOps standard.

.Description
The Set-DeploymentConditionsForStage script block sets the DMO-EUW stage in the -RelDef release definition to the DevOps standard.
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
	[PSCustomObject]$RelDef,
	[Parameter(Mandatory=$false)]
	[PSCustomObject]$StageName = "DEV-EUW"
)
$isModified = $false;
$writeOutput = @();
return [PSCustomObject]@{
	IsModifed = $isModified;
	RelDef = $relDef;
	WriteOutput = $writeOutput;
}
