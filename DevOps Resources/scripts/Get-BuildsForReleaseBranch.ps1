<#
.Synopsis
Generate the commands to build all of the artifacts needed for a release.

.Description
The Get-BuildsForReleaseBranch script generates the commands to build all of the artifacts needed for the -Release release.

.Parameter Release
This is the release branch  and is used to access the '.\ReleaseDefinitions\CTP\Release 9.9' folder where '9.9' is the proved value for -Release.

.Parameter Definitions
This is the set of release definition filenames to include in the results. If none are specified, all release definitions will be used.

.Example
Get-BuildsForReleaseBranch -Release 9.4

This gets all of the builds for Release 9.4.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release,
	[Parameter(Mandatory=$false)]
	[object[]]$Definitions
)
$path = ".\ReleaseDefinitions\CTP\Release {0}" -f $Release;
$jsonFiles = Get-ChildItem -Path $path -Filter '*.json';
$includeAll = $null -eq $Definitions;
$jsonFiles | ForEach-Object {
	$jsonFile = $_;
	$fileName = $jsonFile.Name;
	if ($includeAll -or $Definitions -contains $fileName)
	{
		Write-Verbose ("Processing '{0}'" -f $jsonFile.Name);
		$releaseDefinition = Get-Content $jsonFile.FullName | ConvertFrom-Json;
		$buildArtifact = $releaseDefinition.artifacts | Where-Object isPrimary;
		$buildPipelineName = $buildArtifact.definitionReference.definition.name;
		$buildPipelineId = $buildArtifact.definitionReference.definition.id;
		Write-Output ("New-ReleaseBuild -Release {0} -PipelineId {1} -PipelineName '{2}';" -f $Release,$buildPipelineId,$buildPipelineName);
	}
}
