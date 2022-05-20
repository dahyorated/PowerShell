<#
.SYNOPSIS
Start the QA Freeze based on the current sprint and 'Next QA Freeze' variable group.

.DESCRIPTION
This start the QA Freeze based on the current sprint and 'Next QA Freeze' variable group.

A QA freeze is initiated if:
- It is the date specified in the variable group; or
- It is the first day of a sprint and the current sprint is the sprint specified in the variable group; or
- It is the first day of a sprint and no sprint or date is specified in the variable group.

The QA freeze is initiated by updating -WorkItemId to an Active state.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Team
This is a team for which the sprints are defined.

.PARAMETER WorkItemId
This is the ID of the work item used to control QA freezes.

.PARAMETER TestWorkItemId
This is the ID of the test work item used in lieu of -WorkItemId.

.PARAMETER StartFreeze
This forces a QA freeze to be initiated.

.PARAMETER NoUpdate
This is only used for testing and prevents updating of the -WorkItemId work item.

.PARAMETER UseTest
This forces -TestWorkItemId to replace -WorkItemId. It is only used for testing.

.PARAMETER IterationStartsToday
This is only used for testing and forces an iteration to start on the current date.

.Parameter IpSprint
This forces the current sprint to be the IP sprint.

#>
[CmdletBinding()]
param (
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps",
	[Parameter(Mandatory=$False)]
	[string]$WorkItemId = "89645", # Actual work item
	[string]$TestWorkItemId = "92745", #Test work item
	[switch]$StartFreeze,
	[switch]$NoUpdate,
	[switch]$UseTest,
	[switch]$IterationStartsToday,
	[switch]$IpSprint
)

class QaFreezeControl {
	[string]$StartSprint
	[string]$StartDate
}

Function Get-NextQaFreeze
{
	param(
	)
	$variableGroup = Get-VariableGroup 'Next QA Freeze' $tfsBaseUrl $teamProject $authHeader;
	$variables = $variableGroup.variables;
	$startDate = $variables.StartDate.value;
	if (-not [string]::IsNullOrWhiteSpace($startDate))
	{
		$startDate = (Get-Date $startDate).Date | Get-Date -Format s;
	}
	$control = [QaFreezeControl]
	@{
		StartSprint = $variables.StartSprint.value
		StartDate = $startDate
	}
	return $control;
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
if ($UseTest)
{
	$WorkItemId = $TestWorkItemId;
}
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose "orgURL: '$($orgUrl)'";
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Output "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Output "SYSTEM_TEAMPROJECT = '$teamProject'";
$qaFreezeControl = Get-NextQaFreeze;
Write-Verbose "StartDate: $($qaFreezeControl.StartDate)";
Write-Verbose "StartSprint: $($qaFreezeControl.StartSprint)";
$currentIteration = Get-CurrentIteration $tfsBaseUrl $teamProject $Team $authHeader;
Write-Verbose ($currentIteration | ConvertTo-Json -Depth 100);
$iterationEndDate = $currentIteration.attributes.finishDate.TrimEnd("Z");
$iterationStartDate = $currentIteration.attributes.startDate.TrimEnd("Z");
$iterationName = $currentIteration.name;
$sprintNameParts = Get-SprintNameParts $iterationName;
$majorVersion = $sprintNameParts[1];
$minorVersion = $sprintNameParts[3];
if ($IpSprint -or ($sprintNameParts[2] -eq "IP"))
{
	$currentPiIterations = Get-AllPiIterations $sprintNameParts $orgUrl $ProjectName $Team $authHeader;
	$ipSprintNumber = $currentPiIterations.Count;
	Write-Verbose "Current IP sprint is Sprint: $ipSprintNumber";
	$minorVersion = $ipSprintNumber.ToString();
}
$currentSprint = "{0}.{1}" -f $majorVersion,$minorVersion;
Write-Verbose ("Iteration period for {0}({1}): {2} to {3}" -f $iterationName,$currentSprint,$iterationStartDate,$iterationEndDate);
$currentDate =  (Get-Date).ToUniversalTime().Date | Get-Date -Format s;
Write-Verbose ("Today is {0}" -f $currentDate);
Write-Verbose ("Sprint start date is '{0}'" -f $qaFreezeControl.StartDate);
if ($IterationStartsToday)
{
	# BEGIN Force change today
	$iterationStartDate = $currentDate;
	# END Force change today
}
$startDate = $qaFreezeControl.StartDate;
$startSprint = $qaFreezeControl.StartSprint;
if ([string]::IsNullOrWhiteSpace($startSprint) -and [string]::IsNullOrWhiteSpace($startDate))
{
	$startDate = $iterationStartDate;
	$startSprint = $currentSprint;
}
if (-not [string]::IsNullOrWhiteSpace($startSprint) -and ($startSprint -eq $currentSprint) -and [string]::IsNullOrWhiteSpace($startDate))
{
	$startDate = $iterationStartDate;
}
$initiateQaFreeze = $StartFreeze -or ($startDate -eq $currentDate);
if (-not $initiateQaFreeze)
{
	Write-Output "QA freeze is not starting today."
	Exit;
}
Write-Output "Initiating QA freeze."
# Update Work item
# https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items?view=azure-devops-rest-5.1
# PATCH https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=5.1
# https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_apis/wit/workItems/89645?api-version=5.1
$updatePatch = "_apis/wit/workItems/{0}?api-version=5.1" -f $WorkItemId;
$updatePatchUri = [uri]::EscapeUriString(($tfsBaseUrl,$updatePatch -join '/'));
$contentType = "application/json-patch+json";
$updateBody = @"
[
	{
		"op": "replace",
		"path": "/fields/System.State",
		"value": "Active"
	},
	{
		"op": "add",
		"path": "/fields/System.History",
		"value": "Starting QA Freeze"
	}
]
"@;
if (-not $NoUpdate)
{
	Write-Verbose "Invoking update."
	$updateJson = Invoke-RestMethod -Uri $updatePatchUri -Method Patch -ContentType $contentType -Headers $authHeader -Body $updateBody;
	Write-Verbose $updateJson;
}
else
{
	Write-Verbose "Skipping update."
}
