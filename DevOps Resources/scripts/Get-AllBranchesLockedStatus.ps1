<#
.Synopis
Get the lock status of managed branches in all release repositories.

.Description
The Get-AllBranchesLockedStatus script gets the lock status of managed branches in all release repositories.

.Parameter XlsxFile
This is the pathname of the XLSX file to create.

.Parameter ReleaseRepositories
This is the set of repositories to process.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$false,ValueFromPipeline)]
	[ValidateScript({
		if(!($_ | Split-Path | Test-Path) )
		{
			throw "Folder for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$XlsxFile = "$pwd\Branches.xlsx",
	[Parameter(Mandatory=$false)]
	[string]$ReleaseRepositories = "ReleaseRepositories.json",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Get-AllBranchesInRepository()
{
	param(
		[string]$RepositoryId,
		[string]$Filter,
		[string]$BaseUrl,
		[Hashtable]$Header
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/git/refs/list?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/refs?filter={filter}&latestStatusesOnly={latestStatusesOnly}&api-version=5.1
	$projectsUrl = "{0}_apis/git/repositories/{1}/refs?filter=heads/{2}&latestStatusesOnly=true&api-version=5.1" -f $BaseUrl,$RepositoryId,$Filter;
	return Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $Header;
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting Get-AllBranchesLockedStatus: XLSX file will be saved in '{0}'." -f $XlsxFile);
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader -token $Token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $coreAreaId;
$controlInformation = Get-Content "$PSScriptRoot\$ReleaseRepositories" | ConvertFrom-Json;
$count = $controlInformation.repositories.Count;
$repositories = $controlInformation.repositories;
Write-Output ("Processing {0} repositories." -f $count);
$lockStatus = New-Object System.Collections.ArrayList;
for ($repoIndex = 0; $repoIndex -lt $count; $repoIndex++)
{
	$repositoryName = $repositories[$repoIndex];
	Write-Output "Processing '$repositoryName'.";
	$repository = Get-Repository -RepositoryName $repositoryName -BaseUrl $orgUrl -TeamProject $ProjectName -AuthHeader $authHeader;
	$repositoryId = $repository.id;
	$developBranches = Get-AllBranchesInRepository -RepositoryId $repositoryId -Filter 'develop' -BaseUrl $tfsBaseUrl -Header $authHeader;
	foreach ($branch in $developBranches.value)
	{
		$branchName = $branch.name.Replace("refs/heads/","");
		$isLocked = if ($branch.isLocked -eq'true') {$true} else {$false};
		$newLockStatus = [PSCustomObject]@{
			Repository = $repositoryName;
			Branch = $branchName;
			IsLocked = $isLocked;
		};
		$index = $lockStatus.Add($newLockStatus);
		Write-Verbose ("Added `$lockStatus[{0}]" -and$index);
	}
	$releaseBranches = Get-AllBranchesInRepository -RepositoryId $repositoryId -Filter 'Release/PI' -BaseUrl $tfsBaseUrl -Header $authHeader;
	foreach ($branch in $releaseBranches.value)
	{
		$branchName = $branch.name.Replace("refs/heads/","");
		$isLocked = if ($branch.isLocked -eq'true') {$true} else {$false};
		$newLockStatus = [PSCustomObject]@{
			Repository = $repositoryName;
			Branch = $branchName;
			IsLocked = $isLocked;
		};
		$index = $lockStatus.Add($newLockStatus);
		Write-Verbose ("Added `$lockStatus[{0}]" -and$index);
	}
	if ($lockStatus.Count -eq 0)
	{
		$errorMessage = "{0}: Get-AllBranchesInRepository failed." -f $repositoryName;
		Stop-ProcessError -errorMessage $errorMessage;
	}
}
$lockStatus = $lockStatus | Sort-Object Branch,Repository;
$lockStatus;
Import-Module ImportExcel;
