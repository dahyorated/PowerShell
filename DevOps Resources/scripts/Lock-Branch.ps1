<#
.Synopsis
Lock or unlock a branch in a repository.

.Description
The Lock-Branch script locks or unlocks the -BranchName branch in the -RepositoryId repository.

.Example
Lock-Branch;

This example locks the "develop" branch in the "Global Tax Platform" repository.

.Parameter BranchName
This is the name of the branch to lock or unlock.

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

.Parameter Unlock
This specifies that the script should unlock the -BranchName branch (instead of locking the -BranchName branch).

.Example
Lock-Branch -BranchName "Release/PI8.4";

This example locks the "Release/PI8.4" branch in the "Global Tax Platform" repository.

.Example
Lock-Branch -Unlock;

This example unlocks the "develop" branch in the "Global Tax Platform" repository.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[string]$BranchName = "develop",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryId = "d6390fca-5c08-4c75-b7d4-b2a2b09245f4",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Token = ${env:SYSTEM_ACCESSTOKEN},
	[switch]$Unlock
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader -token $Token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $coreAreaId;
if (-not [string]::IsNullOrEmpty($RepositoryName))
{
	$repository = Get-Repository -RepositoryName $RepositoryName -BaseUrl $tfsBaseUrl -TeamProject $ProjectName -AuthHeader $authHeader;
	$RepositoryId = $repository.id;
}
if ($Unlock)
{
	$payload = @{
		isLocked = $false
	};
}
else
{
	$payload = @{
		isLocked = $true
	};
}
$payloadJson = $payload | ConvertTo-Json -Compress;
# PATCH https://{instance}/fabrikam/_apis/git/repositories/{repositoryId}/refs?filter=heads/master&api-version=5.0
$projectsUrl = "$($tfsBaseUrl)_apis/git/repositories/$($RepositoryId)/refs?filter=heads/$($BranchName)&api-version=5.0";
$currentRefs = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $authHeader;
$isLocked = $currentRefs.value.isLocked;
if (($Unlock -and (-not $isLocked)) -or ((-not $Unlock) -and $isLocked))
{
	Write-Output "No change in locking needed."
	Exit;
}
if ($PSCmdlet.ShouldProcess($RepositoryName))
{
	$lockResults = Invoke-RestMethod -Uri $projectsUrl -Method Patch -ContentType "application/json" -Headers $authHeader -Body $payloadJson;
}
