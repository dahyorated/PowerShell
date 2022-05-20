<#
.Synopsis
Start a new build.

.Description
The New-ReleaseBuild script starts a new build for the build -PipelineName in the -Release branch.

The -PipelineId is required to disambiguate potential duplicates or renames of the build pipeline name.

.Parameter Release
This is the targeted branch for the build.

.Parameter PipelineName
This is the name of the build pipeline. It is only used for displayed information.

.Parameter PipelineId
This is the Azure DevOps identifier for the build pipeline.

.Example
New-ReleaseBuild -Release 9.4 -PipelineId 161 -PipelineName 'UserService Databases - CI';

This starts a build of 'UserService Databases - CI' using code in the 'Release/PI9.4' branch.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release,
	[Parameter(Mandatory=$true)]
	[int]$PipelineId,
	[Parameter(Mandatory=$true)]
	[string]$PipelineName
)
$branch = "Release/PI{0}" -f $Release;
$resultsJson = az pipelines build queue --branch $branch --definition-id $PipelineId;
$results =$resultsJson | ConvertFrom-Json;
Write-Output ("Building '{0}'({1}): Build Number = '{2}'." -f $PipelineName,$PipelineId,$results.buildNumber);
