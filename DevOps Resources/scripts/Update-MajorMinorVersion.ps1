<#
.SYNOPSIS
Update the major/minor version if needed.

.DESCRIPTION
If needed, the Update-MajorMinorVersion script updates the major/minor version in -GroupName.

.PARAMETER GroupName
This is the name of the variable group containing the major/minor version.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Team
This is a team for which the sprints are defined.

.PARAMETER FakeIpSprint
This is used in testing to force the IP sprint processing to occur.

.Parameter NoUpdate
This is used in testing to skip updating the variable group.

.Parameter UseTest
If specified, this forces the script to use the test version of -GroupName (i.e., the -GroupName with a "Test" suffix).

.EXAMPLE
UpdateMajorMinorVersion -GroupName "MajorMinorVersionTest"

This forces the processing to occur on the "MajorMinorVersionTest" variable group.

#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)]
	[string]$GroupName = "MajorMinorVersion",
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps",
	[switch]$FakeIpSprint,
	[switch]$NoUpdate,
	[switch]$UseTest
)

Function Get-CurrentIterationVersion
{
	param (
	)
	$currentIteration = Get-CurrentIteration $orgUrl $ProjectName $Team $authHeader;
	$script:iterationName = $currentIteration.name;
	$sprintNameParts = Get-SprintNameParts $iterationName;
	$script:majorVersion = $sprintNameParts[1];
	$script:minorVersion = $sprintNameParts[3];
	if ($FakeIpSprint)
	{
		$sprintNameParts[2] = "IP";
	}
	if ($sprintNameParts[2] -eq "IP")
	{
		$currentPiIterations = Get-AllPiIterations $sprintNameParts $orgUrl $ProjectName $Team $authHeader;
		$ipSprintNumber = $currentPiIterations.Count;
		Write-Verbose "Current IP sprint is Sprint: $ipSprintNumber";
		$script:minorVersion = $ipSprintNumber.ToString();
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
if ($UseTest)
{
	$GroupName = "{0}Test" -f $GroupName;
}
$AuthHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
$variableGroup = Get-VariableGroup $GroupName $tfsBaseUrl $teamProject $AuthHeader;
$majorMinorVersion = $variableGroup.variables.MajorMinorVersionDevelop.value;
$oldSprint = $majorMinorVersion.TrimEnd(".0");
Write-Output ("##vso[task.setvariable variable=PreviousSprint;]$oldSprint");
Write-Verbose "Old version: $majorMinorVersion";
Get-CurrentIterationVersion;
$newMajorMinorVersion = "{0}.{1}.0" -f $majorVersion,$minorVersion;
Write-Verbose "New version: $newMajorMinorVersion";
if ($newMajorMinorVersion -ne $majorMinorVersion)
{
	Write-Output "$($iterationName): Updating MajorMinorVersionDevelop $majorMinorVersion to $newMajorMinorVersion";
	$variableGroup.variables.MajorMinorVersionDevelop = $newMajorMinorVersion;
	$variableGroup.PSObject.Properties.Remove('createdBy');
	$variableGroup.PSObject.Properties.Remove('createdOn');
	$variableGroup.PSObject.Properties.Remove('modifiedBy');
	$variableGroup.PSObject.Properties.Remove('modifiedOn');
	$variableGroup.PSObject.Properties.Remove('isShared');
	if (!($NoUpdate))
	{
		$updatedVariableGroupJson = Update-VariableGroup $variableGroup $tfsBaseUrl $teamProject $AuthHeader;
	}
}
else
{
	Write-Output "$($iterationName): No need to update MajorMinorVersionDevelop $majorMinorVersion today."
}
