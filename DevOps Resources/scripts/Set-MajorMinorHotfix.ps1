<#
.SYNOPSIS
Set the hot fix number for a release branch.

.DESCRIPTION
The Set-MajorMinorHotfix script sets the hot fix number to -Hotfix for the -Release in -GroupName.

.Parameter Release
This is the release to update.

.Parameter HotfixVersion
This is the new value for the hot fix version.

.PARAMETER GroupName
This is the name of the variable group containing the major/minor version.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Team
This is a team for which the sprints are defined.

.Parameter UseTest
If specified, this forces the script to use the test version of -GroupName (i.e., the -GroupName with a "Test" suffix).

.Parameter NoUpdate
If specified this skips updating the variable group. This supports testing.

.Parameter SaveUpdateJson
If specified, this save the update JSON to "$global:jsonSave".

.EXAMPLE
Set-MajorMinorHotfix -Release 8.4 -HotfixVersion 5 -UseTest

This sets the hot fix version to 5 for release 8.4 in the "MajorMinorVersion" variable group.

.EXAMPLE
Set-MajorMinorHotfix -Release 8.4 -HotfixVersion 5 -UseTest

This sets the hot fix version to 5 for release 8.4 in the "MajorMinorVersionTest" variable group.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release,
	[Parameter(Mandatory=$True)]
	[ValidateRange(1,19)]
	[int]$HotfixVersion,
	[Parameter(Mandatory=$False)]
	[string]$GroupName = "MajorMinorVersion",
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps",
	[switch]$UseTest,
	[switch]$NoUpdate,
	[switch]$SaveUpdateJson
)

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
if ($UseTest)
{
	$GroupName = "{0}Test" -f $GroupName;
}
Write-Verbose "GroupName: $GroupName";
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = (Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId).TrimEnd("/");
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
$vg = Get-VariableGroup $GroupName $tfsBaseUrl $ProjectName $authHeader;
$variableGroupId = $vg[0].id;
$x = $vg[0];
$xvo = $x.variables.MajorMinorVersionOther;
$other = ($xvo.value | ConvertFrom-Json);
Write-Verbose $other;
if ($other.name -ne 'MajorMinorVersionOther')
{
	$errorMessage = "'{0}' is not the correct name for the MajorMinorVersionOther variable JSON content." -f ($other.name);
	Stop-ProcessError $errorMessage;
}
if ($other.version -ne 1)
{
	$errorMessage = "'{0}' is an unsupported version for the MajorMinorVersionOther variable JSON content." -f ($other.version);
	Stop-ProcessError $errorMessage;
}
$rl =[System.Collections.ArrayList]$other.releases;
if ($IsVerbose)
{
	Write-Output "Before:";
	$rl;
}
$rlm = $rl | Where-Object branch -eq $Release;
if ($null -eq $rlm)
{
	$errorMessage = "There is no release that matches '{0}." -f $Release;
	Stop-ProcessError $errorMessage;
}
$rlm.hotfixVersion = $HotfixVersion;
if ($IsVerbose)
{
	Write-Output "Updated: ";
	$rlm;
}
$other.releases = [array]$rl;
if ($IsVerbose)
{
	Write-Output "After: ";
	$other.releases;
}
$x.variables.MajorMinorVersionOther = $other | ConvertTo-Json -Depth 100 -Compress;
$x.PSObject.Properties.Remove('createdBy');
$x.PSObject.Properties.Remove('createdOn');
$x.PSObject.Properties.Remove('modifiedBy');
$x.PSObject.Properties.Remove('modifiedOn');
$x.PSObject.Properties.Remove('isShared');
if ($SaveUpdateJson)
{
	$variableGroupJson = $x | ConvertTo-Json -Depth 100 -Compress;
	$global:saveJson = $variableGroupJson;
}
if (!($NoUpdate))
{
	$updatedVariableGroupJson = Update-VariableGroup $x $tfsBaseUrl $ProjectName $authHeader;
	Write-Verbose $updatedVariableGroupJson;
}
