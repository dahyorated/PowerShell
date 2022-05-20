<#
.SYNOPSIS
Set MajorMinorOther to the current template.

.DESCRIPTION
The Set-MajorMinorOther script sets MajorMinorOther, in -GroupName, to the current template.

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
If specified, this saves the update JSON to "$global:jsonSave".

.EXAMPLE
Set-MajorMinorOther

This sets MajorMinorOther in the "MajorMinorVersion" variable group.

.EXAMPLE
Set-MajorMinorOther -NoUpdate -SaveUpdateJson

This prepares to set MajorMinorOther in the "MajorMinorVersion" variable group.
- The variable group is not updated.
- The JSON for the updated is stored in "$global:jsonSave".

.EXAMPLE
Set-MajorMinorOther -UseTest

This sets MajorMinorOther in the "MajorMinorVersionTest" variable group.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$TemplateFile = "$PSScriptRoot\Template-MajorMinorVersionOther.json",
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
$x = $vg[0];
$template = Get-Content -Path $TemplateFile | ConvertFrom-Json;
$x.variables.MajorMinorVersionOther.value = $template | ConvertTo-Json -Depth 100 -Compress;
$x.PSObject.Properties.Remove('createdBy');
$x.PSObject.Properties.Remove('createdOn');
$x.PSObject.Properties.Remove('modifiedBy');
$x.PSObject.Properties.Remove('modifiedOn');
$x.PSObject.Properties.Remove('isShared');
if ($SaveUpdateJson)
{
	$global:saveJson = $x | ConvertTo-Json -Depth 100 -Compress;
}
Write-Verbose "uriVariableGroupPut: $uriVariableGroupPut";
if ($NoUpdate)
{
	Write-Output ("Skipping update of '{0}'." -f $GroupName);
}
else
{
	Write-Output ("Updating '{0}'." -f $GroupName);
	$updatedVariableGroupJson = Update-VariableGroup $x $tfsBaseUrl $ProjectName $authHeader;
	if ($IsVerbose)
	{
		Write-Output "Update Response:";
		Write-Output ($updatedVariableGroupJson | ConvertTo-Json -Depth 100 -Compress);
	}
}
