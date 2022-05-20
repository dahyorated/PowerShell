<#
.SYNOPSIS
Set policies on a new release branch.

.DESCRIPTION
This sets policies on a new release branch named "Release/{BranchName}" where {BranchName} is the value of -BranchName.
The policies are copied from the "develop" branch.

.PARAMETER BranchName
This is the name of the lowest leaf of the branch name.

.PARAMETER RepositoryId
This is the ID for the "Global Tax Platform" repository.

.Parameter RepositoryName
This is the Azure DevOps name for the repository containing -BranchName. This overrides the value of -RepositoryId.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.EXAMPLE
Set-ReleaseBranchPolicy -BranchName "PI9.1"

This creates the Release/PI9.1 branch based on the "develop" branch.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[string]$BranchName = "Test",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryId = "d6390fca-5c08-4c75-b7d4-b2a2b09245f4",
	[Parameter(Mandatory=$false)]
	[string]$RepositoryName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Clean-UnusedProperty
{
	param(
		[PSCustomObject]$cleanMeElement,
		[string]$PropertyName
	)
	if (($cleanMeElement.Keys -contains $PropertyName) -or ($PropertyName -in $cleanMeElement.PsObject.Properties.Name))
	{
		$cleanMeElement.PSObject.Properties.Remove($PropertyName);
	}
}

Function Clear-PolicyObjectUnusedProperty
{
	param(
	[PSCustomObject]$cleanMe
	)
	if ($null -eq $cleanMe)
	{
		return;
	}
	Clean-UnusedProperty $cleanMe 'createdBy';
	Clean-UnusedProperty $cleanMe 'createdDate';
	Clean-UnusedProperty $cleanMe '_links';
	Clean-UnusedProperty $cleanMe 'id';
	Clean-UnusedProperty $cleanMe 'revision';
	Clean-UnusedProperty $cleanMe 'url';
	Clean-UnusedProperty $cleanMe 'isEnterpriseManaged';
	Clean-UnusedProperty $cleanMe.type 'url';
	Clean-UnusedProperty $cleanMe.type 'displayName';
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$developBranch = "refs/heads/develop";
$releaseBranch = "refs/heads/Release/{0}" -f $BranchName;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
if (-not [string]::IsNullOrEmpty($RepositoryName))
{
	Write-Output ("Setting policies for 'Release/{0}' branch in the '{1}' repository." -f $BranchName,$RepositoryName);
	$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $coreAreaId;
	$repository = Get-Repository -RepositoryName $RepositoryName -BaseUrl $tfsBaseUrl -TeamProject $ProjectName -AuthHeader $authHeader;
	$RepositoryId = $repository.id;
}
if ($null -eq $RepositoryId)
{
	$errorMessage = "RepositoryId is null.";
	Stop-ProcessError $errorMessage;
}
# https://docs.microsoft.com/en-us/rest/api/azure/devops/git/policy%20configurations/get?view=azure-devops-rest-5.1
$uriTemplate = "{0}/{1}/_apis/git/policy/configurations?repositoryId={2}&refName={3}&api-version=5.1-preview.1";
$uriGetDevelop = $uriTemplate -f $orgUrl,$ProjectName,$RepositoryId,$developBranch;
$uriGetRelease = $uriTemplate -f $orgUrl,$ProjectName,$RepositoryId,$releaseBranch;
$developBranchPolicies = Invoke-RestMethod -Uri $uriGetDevelop -Headers $authHeader -Method Get -ContentType application/json;
$releaseBranchPolicies = Invoke-RestMethod -Uri $uriGetRelease -Headers $authHeader -Method Get -ContentType application/json;
Write-Output ("develop branch has {0} policies." -f $developBranchPolicies.Count);
Write-Output ("release branch has {0} policies." -f $releaseBranchPolicies.Count);
$developPolicies = $developBranchPolicies.value;
$releasePolicies = $releaseBranchPolicies.value;
#$developPolicies | ConvertTo-Json -Depth 100 | Out-File "policies.json";
$minReviewersDevelop = $developPolicies | Where-Object {$_.type.displayName -eq "Minimum number of reviewers"};
$minReviewersRelease = $releasePolicies | Where-Object {$_.type.displayName -eq "Minimum number of reviewers"};
Clear-PolicyObjectUnusedProperty $minReviewersDevelop;
$minReviewersDevelop.settings.scope | Add-Member -NotePropertyName refName -NotePropertyValue "$releaseBranch" -Force;
# TODO Allow for multiple matches
[array]$gtpGatesDevelop = $developPolicies | Where-Object {$_.IsEnabled -and $_.type.displayName -eq "Build" -and $_.settings.displayName -like 'Global Tax*'};
[array]$gtpGatesRelease = $releasePolicies | Where-Object {$_.IsEnabled -and $_.type.displayName -eq "Build" -and $_.settings.displayName -like 'Global Tax*'};
for ($i = 0; $i -lt $gtpGatesDevelop.Count; $i++)
{
	Clear-PolicyObjectUnusedProperty $gtpGatesDevelop[$i];
	$gtpGatesDevelop[$i].settings.scope | Add-Member -NotePropertyName refName -NotePropertyValue "$releaseBranch" -Force;
}
[array]$requiredReviewersDevelop = $developPolicies | Where-Object {$_.type.displayName -eq "Required reviewers"};
[array]$requiredReviewersRelease = $releasePolicies | Where-Object {$_.type.displayName -eq "Required reviewers"};
for ($i = 0; $i -lt $requiredReviewersDevelop.Count; $i++)
{
	Clear-PolicyObjectUnusedProperty $requiredReviewersDevelop[$i];
	$requiredReviewersDevelop[$i].settings.scope | Add-Member -NotePropertyName refName -NotePropertyValue "$releaseBranch" -Force;
}

# create policies if policies do not exist.
# doc: https://docs.microsoft.com/en-us/rest/api/azure/devops/policy/configurations/create?view=azure-devops-rest-5.1
# POST https://dev.azure.com/fabrikam/fabrikam-fiber-git/_apis/policy/configurations?api-version=5.1
$uriCreatePolicy = "{0}/{1}/_apis/policy/configurations?api-version=5.1" -f $orgUrl,$ProjectName;
if ($IsVerbose)
{
	Write-Output ($minReviewersDevelop | ConvertTo-Json -Depth 100);
}
if (($null -eq $minReviewersRelease) -and $PSCmdlet.ShouldProcess("Set Min Reviewers"))
{
	Write-Output "Setting Min Reviewers:";
	$minReviewersJson = $minReviewersDevelop | ConvertTo-Json -Depth 100 -Compress;
	$global:responseMin = Invoke-RestMethod -Uri $uriCreatePolicy -Headers $authHeader -Method POST -ContentType application/json -Body $minReviewersJson;
}
if ($IsVerbose)
{
	Write-Output ($gtpGateDevelop | ConvertTo-Json -Depth 100);
}
if (($gtpGatesRelease.Count -eq 0) -and ($gtpGatesDevelop.Count -ne 0) -and $PSCmdlet.ShouldProcess("Set Gates"))
{
	Write-Output "Setting Gates:";
	foreach ($gtpGateDevelop in $gtpGatesDevelop)
	{
		$gtpGateJson = $gtpGateDevelop | ConvertTo-Json -Depth 100 -Compress;
		$global:responseGate = Invoke-RestMethod -Uri $uriCreatePolicy -Headers $authHeader -Method POST -ContentType application/json -Body $gtpGateJson;
	}
}
if ($IsVerbose)
{
	Write-Output ($requiredReviewersRelease | ConvertTo-Json -Depth 100);
}
if (($requiredReviewersRelease.Count -eq 0) -and $PSCmdlet.ShouldProcess("Set Required Reviewers"))
{
	Write-Output "Setting Required Reviewers:";
	for ($i = 0; $i -lt $requiredReviewersDevelop.Count; $i++)
	{
		$requiredReviewersJson = $requiredReviewersDevelop[$i] | ConvertTo-Json -Depth 100 -Compress;
		$responseReq = Invoke-RestMethod -Uri $uriCreatePolicy -Headers $authHeader -Method POST -ContentType application/json -Body $requiredReviewersJson;
		Write-Output ("Adding reviewer for file pattern '{0}'." -f $requiredReviewersDevelop[$i].settings.filenamePatterns);
	}
}
