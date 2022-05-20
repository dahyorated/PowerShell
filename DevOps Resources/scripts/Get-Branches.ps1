<#
.Synopis
Get all of the branches for a repository.

.Description
The Get-Branches script gets all of the branches for the -RepositoryName repository.

.Parameter CsvFile
This is the pathname of the CSV file to create.

.Parameter RepositoryName
This is the name of the repository to process.

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
	[System.IO.FileInfo]$CsvFile = "$pwd\Branches.csv",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Token = ${env:SYSTEM_ACCESSTOKEN}
)

function New-BranchStatus()
{
	param(
		[string]$BranchType,
		[string]$BranchName,
		[string]$CreatorName
	)
	return [PSCustomObject]@{
		BranchType = $BranchType
		BranchName = $BranchName
		CreatedBy = $CreatorName
	};
}

function Format-Branch()
{
	param(
	[PSCustomObject]$branch
	)
	return '"{0}","{1}","{2}"' -f $branch.BranchType,$branch.BranchName,$branch.CreatedBy;
}

function Format-Header()
{
	param(
	[string]$prefix
	)
	return "BranchType,BranchName,CreatedBy";
}

Function Get-Branches()
{
	param(
		[string]$repositoryId
	)
	$found = $false;
	$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
	$projectsUrl = "$($tfsBaseUrl)_apis/git/repositories/$($repositoryId)/refs?includeStatuses=true&latestStatusesOnly=true&api-version=5.1";
	$script:branches = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header;
	$found = $true;
	return $found;
}

# TODO Update to new DevOps; add RepostoryName processing

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting Get-Branches: CSV file will be saved in '{0}'." -f $CsvFile);
# core variables
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$separator = "/";
$repository = Get-Repository -RepositoryName $RepositoryName -BaseUrl $orgUrl -TeamProject $ProjectName -AuthHeader $header;
if (!(Get-Branches($repository.id)))
{
	$errorMessage = "'{0}' does not exist in account '{1}'. " -f $ProjectName,$Account;
	Stop-ProcessError -errorMessage $errorMessage;
}
$extracts = New-Object System.Collections.ArrayList;
$branches.value |
	ForEach-Object {
		$branch = $_;
		$namePart = $branch.name -split $separator,3;
		$branchType = $namePart[1];
		$branchName = $namePart[2];
		$creatorName = $branch.creator.displayName;
		$newExtract = New-BranchStatus $branchType $branchName $creatorName;
		$newIndex = $extracts.Add($newExtract);
	}
;
$csv = @();
$csv += Format-Header;
$extracts |
	ForEach-Object {
		$csv += Format-Branch $_;
	}
$csv | Out-File -FilePath $CsvFile;
Write-Output "Ending Get-Branches";
