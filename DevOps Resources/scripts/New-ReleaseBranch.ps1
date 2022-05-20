<#
.SYNOPSIS
Create a new release branch.

.DESCRIPTION
The New-ReleaseBranch script creates a new release branch (in -RepositoryName) named "Release/{BranchName}" where {BranchName} is the value of -BranchName.

.PARAMETER BranchName
This is the name of the lowest leaf of the branch name.

.PARAMETER RepositoryId
This is the ID for an Azure DevOps repository to contain -BranchName.

.Parameter RepositoryName
This is the name for the Azure DevOps repository to contain -BranchName. This overrides the value of -RepositoryId.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.EXAMPLE
New-ReleaseBranch -BranchName "PI9.1"

This creates the Release/PI9.1 branch based on the "develop" branch.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[ValidatePattern('^PI[0-9]+\.[0-9]+$')]
	[string]$BranchName = "PI99.99",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryId = "d6390fca-5c08-4c75-b7d4-b2a2b09245f4",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryName = 'Global Tax Platform',
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Token = ${env:SYSTEM_ACCESSTOKEN}
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $coreAreaId;
if (-not [string]::IsNullOrEmpty($RepositoryName))
{
	$repository = Get-Repository -RepositoryName $RepositoryName -BaseUrl $tfsBaseUrl -TeamProject $ProjectName -AuthHeader $authHeader;
	$RepositoryId = $repository.id;
}
$uriList = "https://dev.azure.com/{0}/{1}/_apis/git/repositories/{2}/refs?api-version=5.1" -f $Account,$ProjectName,$RepositoryId;
$response = Invoke-RestMethod -Uri $uriList -Headers $authheader -Method Get -ContentType application/json;
Write-Verbose $response.count;
$refs = $response.value;
if ($isVerbose)
{
	$refs | Where-Object name -like 'refs/heads/Release/*' | Select-Object name,objectId;
}
$developBranch = $refs | Where-Object name -eq 'refs/heads/develop';
$oldObjectId = $developBranch.objectId;
Write-Output "'develop' branch ID: $oldObjectId";
$requestList = @{
        name ="refs/heads/Release/$BranchName"
        oldObjectId = "0000000000000000000000000000000000000000"
        newObjectId = $oldObjectId
    };
$body = ConvertTo-Json -InputObject @($requestList);
Write-Output $body;
$uriCreate = "https://dev.azure.com/{0}/{1}/_apis/git/repositories/{2}/refs?api-version=5.1" -f $Account,$ProjectName,$RepositoryId;
$response = Invoke-RestMethod -Uri $uriCreate -Headers $authHeader -Method Post -Body $body -ContentType application/json;
$newRef = $response.value;
Write-Output $newRef;
