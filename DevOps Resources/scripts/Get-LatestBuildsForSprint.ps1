<#
.Synopsis
Get the latest builds for a sprint.

.Description
The Get-LatestBuildsForSprint script gets the latest builds for the -Sprint sprint in the -BranchName branch.

.Parameter Sprint
This is the sprint used for searching.

.Parameter BranchName
This is the name of the branch to search.

.Parameter Release
This is the targeted release (e.g., 9.9).

.Parameter RepositoryId
This is the Azure DevOps ID for the repository containing -BranchName.

.Parameter RepositoryName
This is the Azure DevOps name for the repository containing -BranchName. This overrides the value of -RepositoryId.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Parameter CoreReleases
This is a JSON file that specifies all of the core database and service release pipelines that must be included in a build.

.Parameter TenantReleases
This is a JSON file that specifies all of the tenant database and service release pipelines that mus be included in a build.

.Parameter CtpRootFolder
This is the folder containing the release definitions saved by Export-ReleaseDefinitions.

.Parameter OutputFolder
This is the folder that will contain two output files for the -Sprint release.
- Clone-9.9_ReleasePipelines.ps1
- Build-9.9_Releases.ps1

.Example
Push-Location C:\EYdev\devops\pipelines;
PS C:\>Get-LatestBuildsForSprint -Sprint 10.2 -BranchName 'Release/PI10.2' -Release 10.3;

PS C:\>Get-LatestBuildsForSprint -Sprint 10.3 -BranchName 'develop' -Release 10.3;

PS C:\>Pop-Location;

This will create or update the output files (i.e., Build-10.3_Releases.ps1 and Clone-10.3_ReleasePipelines.ps1) to include the builds and releases touched in sprint 10.2 and 10.3.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Sprint = "10.2",
	[Parameter(Mandatory=$false)]
	[string]$BranchName = "develop",
	[Parameter(Mandatory=$false)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release = "",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Token = ${env:SYSTEM_ACCESSTOKEN},
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path) )
		{
			throw "Folder '$_' does not exist.";
		}
		if(!($_ | Test-Path -PathType Container) )
		{
			throw "The OutputFolder argument must be a folder. Files are not allowed.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$CoreReleases = "$PSScriptRoot\CoreReleases.json",
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$TenantReleases = "$PSScriptRoot\TenantReleases.json",
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo[]]$CtpRootFolder = @(
		"C:\EYdev\devops\pipelines\ReleaseDefinitions\CTP",
		"C:\EYdev\devops\pipelines\ReleaseDefinitions\CTP\Through UAT-Perf"),
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path) )
		{
			throw "Folder '$_' does not exist.";
		}
		if(!($_ | Test-Path -PathType Container) )
		{
			throw "The OutputFolder argument must be a folder. Files are not allowed.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$OutputFolder = "C:\EYdev\devops\pipelines")

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
if ([string]::IsNullOrWhiteSpace($Release))
{
	$Release = $Sprint;
}
Write-Output ("Targeting release {0}: Processing sprint {1} in branch '{2}'."-f $Release,$Sprint,$BranchName);
$paths = @('\','\APIM','\Train2');
[System.Collections.ArrayList]$rds = @();
[array]$requiredTenant = Get-Content $TenantReleases | ConvertFrom-Json;
[array]$requiredCore = Get-Content $CoreReleases | ConvertFrom-Json;
$ctpFiles = Get-ChildItem -Path $CtpRootFolder -Filter '*.json';
foreach ($ctpFile in $ctpFiles)
{
	$relDef = Get-Content -Path $ctpFile.FullName | ConvertFrom-Json;
	$rdId = $relDef.id;
	[array]$artifacts = $relDef.artifacts | Where-Object isPrimary;
	$bldName = $artifacts[0].definitionReference.definition.name;
	$bldId = $artifacts[0].definitionReference.definition.id;
	$rdName = $relDef.name;
	[array]$uatStage = $relDef.environments | Where-Object name -eq 'UAT-EUW';
	[array]$matchingRd = $rds | Where-Object ReleaseDefName -eq $rdName;
	if ($uatStage.Count -eq 0)
	{
		Write-Output ("Skipping '{0}'. No UAT-EUW stage." -f $ctpFile.FullName);
		continue;
	}
	if ($matchingRd.Count -eq 0)
	{
		$newRd =[PSCustomObject]@{
			BuildDefName = $bldName;
			BuildDefId = $bldId;
			ReleaseDefName = $rdName;
			ReleaseDefId = $rdId;
		};
		$index = $rds.Add($newRd);
		Write-Verbose ("Added '{0}' as `$rds({1})." -f $rdName,$index);
	}
	else
	{
		Write-Output ("{0}: Already exists. Deleting '{1}'." -f $rdName,$ctpFile.FullName);
		Remove-Item $ctpFile.Fullname;
	}
}
$rdsCount = $rds.Count;
Write-Output ("Processed {0} release definitions." -f $rdsCount);
[array]$bds = az pipelines build definition list --top 1000 --organization $org --project $project | ConvertFrom-Json;
$bdsCount = $bds.Count;
Write-Output "Processing $($bdsCount) build definitions.";
$bdsFiltered = $bds | Where-Object { (($_.name -like '* CI') -or ($_.name -like '*-CI')) -and ($paths -contains $_.path)};;
$bdsCount = $bdsFiltered.Count;
Write-Output "Processing $($bdsCount) filtered build definitions.";
$sprintPattern = "{0}.*" -f $Sprint;
$branchFilter = "refs/heads/{0}" -f $BranchName;
$clones = @();
$buildStarts = @();
foreach ($rd in $rds)
{
	$relName = $rd.ReleaseDefName;
	[array]$matchTenant = $requiredTenant | Where-Object pipeline -eq $relName;
	[array]$matchCore = $requiredCore | Where-Object pipeline -eq $relName;
	if (($matchTenant.Count -ne 0) -or ($matchCore.Count -ne 0))
	{
		$bdName = $rd.BuildDefName;
		$bdId = $rd.BuildDefId;
		$clones += "Clone-ReleasePipeline -PipelineName '$relName' -Release $Release";
		$buildStarts += "New-ReleaseBuild -PipelineName '$bdName' -Release $Release -PipelineId $bdId";
	}
}
foreach ($bd in $bdsFiltered)
{
	$bdId = $bd.id;
	$bdName = $bd.name;
	[array]$builds = az pipelines build list --definition-ids $bdId | ConvertFrom-Json;
	[array]$sprintBuilds = $builds |
		Where-Object {($_.buildNumber -like $sprintPattern) -and ($_.result -eq 'succeeded') -and ($_.sourceBranch -eq $branchFilter)};
	if ($sprintBuilds.Count -ne 0)
	{
		Write-Verbose ("Clone the release pipeline for '{0}({1})' pipeline." -f $bdName,$bdId);
		[array]$rd = $rds | Where-Object BuildDefId -eq $bdId;
		if ($rd.Count -eq 0)
		{
			Write-Output ("==> No matching \CTP release definition for {0}" -f $bdName);
			continue;
		}
		$rdCount = $rd.Count;
		if ($rd.Count -ne 1)
		{
			Write-Output ("==> '{0}' has {1} matches." -f $bdName,$rd.Count);
			for ($i = 0; $i -lt $rdCount; $i++)
			{
				Write-Output ("==> Match {0} is '{1}'." -f $i,$rd[$i].ReleaseDefName);
			}
		}
		for ($i = 0; $i -lt $rdCount; $i++)
		{
			$relName = $rd[$i].ReleaseDefName;
			$clones += "Clone-ReleasePipeline -PipelineName '$relName' -Release $Release";
			$buildStarts += "New-ReleaseBuild -PipelineName '$bdName' -Release $Release -PipelineId $bdId";
		}
	}
	else
	{
		Write-Verbose ("Skipping the '{0}({1})' pipeline." -f $bd.name,$bdId);
	}
}
if ($IsVerbose)
{
	Write-Output "Clones:";
	Write-Output "=======";
	$clones;
	Write-Output "Builds:";
	Write-Output "======";
	$buildStarts;
}
else
{
	Write-NameAndValue "Result count" $clones.Count;
}
$clonePathname = [System.Io.Path]::Combine($OutputFolder,"Clone-$($Release)_ReleasePipelines.ps1");
$clones | Out-File -FilePath $clonePathname -Append;
Edit-UniqueContent -Source $clonePathname;
$buildPathname = [System.Io.Path]::Combine($OutputFolder,"Build-$($Release)_Releases.ps1");
$buildStarts | Out-File -FilePath $buildPathname -Append;
Edit-UniqueContent -Source $buildPathname;
