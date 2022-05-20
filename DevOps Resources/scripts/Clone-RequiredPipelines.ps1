<#
.SYNOPSIS
Clone pipelines required for all releases.

.DESCRIPTION
The Clone-RequiredPipelines script clones pipelines required for all releases.
This includes all tenant database and service pipelines as defined in the -JsonTenantReleases control file.

.PARAMETER Release
This is the current release and must be in the form "9.9".

.Parameter JsonTenantReleases
This is a JSON file containing the names of the release pipelines for tenant databases and services.

.EXAMPLE
Clone-RequirePipelines -Release '9.1'

This clones all required pipelines into the '\CTP\Release 9.1' folder.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True)]
	[string]$Release,
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonTenantReleases = "$PSScriptRoot\TenantReleases.json"
)
$targetPath = "\CTP\Release {0}" -f $Release;
$rdToClone = Get-Content $JsonTenantReleases | ConvertFrom-Json;;
$rdToClone | ForEach-Object {
	$rdName = $_.pipeline;
	Write-Output ("Clone-ReleasePipeline -PipelineName $rdName -Release $Release -TargetPath '$targetPath' -StartBuild;");
	Clone-ReleasePipeline -PipelineName $rdName -Release $Release -TargetPath $targetPath -StartBuild;
};
