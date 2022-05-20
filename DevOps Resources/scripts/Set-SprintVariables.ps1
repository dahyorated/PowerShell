<#
.Synopsis
Set the pipeline variables needed to control start of sprint and release activities.

.Description
The Set-SprintVariables script sets the pipeline variables needed to control start of sprint and release activities.

.Parameter Account
This is the Azure DevOps account.

.Parameter ProjectName
This is the Azure DevOps project to search.

.Parameter Team
This is a team for which the sprints are defined.

.Parameter ControlGroupName
This is the name of the variable group used to control the start of sprint and releases.

.Parameter IpSprint
This forces the current sprint to be the IP sprint.

.Parameter TestStartDate
This parameter is only used for testing. It forces the iteration start date to be the specified date.

.Parameter CurrentDateTime
This parameter is only used for testing. It forces the current date/time to be the provided value.

.Parameter UseTest
If specified, the script uses a test version of -ControlGroupName. The test version is the value of -ControlGroupName with a " - Test" suffix.

.Inputs
None.

.Outputs
The following pipeline variables are created or updated.
- CurrentSprint: The sprint that starts on the current date.
- SprintStartDate: The sprint start date.
- IsStartOfSprint: "true" if the current date is the start of a sprint; otherwise "false".
- IsStartOfRelease: "true" if the current date is the start of a release; otherwise "false".
- BranchName: The name of the release branch (lowest level leaf: e.g., PI9.3)

.Example
Set-SprintVariables;
PS C:\>AnotherScript -Xyzzy $(CurrentSprint);

The first command sets the pipeline variables. The second command (in a subsequent pipeline task) uses one of the variables.

.Example
Set-SprintVariables.ps1 -TestStartDate (Get-Date).ToUniversalTime();

This forces the iteration start date to be the current UTC date.
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps",
	[Parameter(Mandatory=$False)]
	[string]$ControlGroupName = "Next QA Freeze",
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonControls = "$PSScriptRoot\SetSprintVariableControls.json",
	[switch]$IpSprint,
	[Parameter(Mandatory=$False)]
	[string]$TestStartDate,
	[Parameter(Mandatory=$False)]
	[datetime]$CurrentDateTime,
	[switch]$UseTest
)

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
[DateTime]$currentDate = (Get-Date).ToUniversalTime().Date;
if ($CurrentDateTime -ne $null)
{
	$currentDate = $CurrentDateTime.ToUniversalTime().Date;
}
$controls = Get-Content $JsonControls | ConvertFrom-Json;
$controlVersion = $controls.version;
$controlName = $controls.name;
$expectedControlName = [System.IO.Path]::GetFileNameWithoutExtension($JsonControls);
if ($controlName -ne $expectedControlName)
{
	$errorMessage = "'$JsonControls' is not a valid control file (name is '$controlName' but should be '$expectedControlName').";
	Stop-ProcessError $errorMessage;
}
if ($controlVersion -ne 1)
{
	$errorMessage = "Version '$controlVersion' is not supported: '$JsonControls'.";
	Stop-ProcessError $errorMessage;
}
$excludedSprints = $controls.excludedSprints;
if ($null -eq $excludedSprints)
{
	$errorMessage = "'$JsonControls' is missing an array of excludedSprints.";
	Stop-ProcessError $errorMessage;
}
if ($UseTest)
{
	$ControlGroupName = "{0} - Test" -f $ControlGroupName;
}
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$nextQaFreeze = Get-VariableGroup $ControlGroupName $orgUrl $ProjectName $authHeader;
Write-Verbose (Get-CurrentLineNumber);
if ($null -ne $nextQaFreeze)
{
	Write-Verbose ($nextQaFreeze | ConvertTo-Json -Depth 100);
}
else
{
	$errorMessage = "Invalid response from Get-VariableGroup for '{0}' in project ''{1}." -f $ControlGroupName,$ProjectName;
	Stop-ProcessError $errorMessage;
}
$variables = $nextQaFreeze.variables;
$branchName = $variables.BranchName.Value;
$overrideStartDate = $variables.StartDate.Value;
$overriderStartSprint = $variables.StartSprint.Value;
$currentIteration = Get-CurrentIteration $orgUrl $ProjectName $Team $authHeader;
if ($null -eq $currentIteration)
{
	$errorMessage = "Missing current iteration for Team '{0}'." -f $Team;
	Stop-ProcessError $errorMessage;
}
Write-Verbose ($currentIteration | ConvertTo-Json -Depth 100);
$iterationName = $currentIteration.name;
if ([string]::IsNullOrEmpty($iterationName))
{
	$errorMessage = "Current iteration name for Team '{0}' is null." -f $Team;
	Stop-ProcessError $errorMessage;
}
else
{
	Write-Output ("Current iteration: {0}" -f $iterationName);
}
$sprintNameParts = Get-SprintNameParts $iterationName;
$piNumber = $sprintNameParts[1];
$sprintNumber = $sprintNameParts[3];
$testSprintNumber = $sprintNumber;
[DateTime]$iterationEndDate = (ConvertTo-Date $currentIteration.attributes.finishDate).ToUniversalTime().Date;
[DateTime]$iterationStartDate = (ConvertTo-Date $currentIteration.attributes.startDate).ToUniversalTime().Date;
if (![string]::IsNullOrWhiteSpace($TestStartDate))
{
	[DateTime]$iterationStartDate = (ConvertTo-Date $TestStartDate).ToUniversalTime().Date;
}
if ($IpSprint)
{
	$sprintNameParts[2] = "IP";
	$testSprintNumber = "IP";
}
Write-Output ("Current date: {0}" -f $currentDate);
if ($currentDate -gt $iterationEndDate)
{
	Write-Output "Processing inter-sprint scenario";
	$currentPiIterations = Get-AllPiIterations $sprintNameParts $orgUrl $ProjectName $Team $authHeader |
		Sort-Object -Property @{Expression = {$_.attributes.startDate}};
	[array]$futurePiIterations = $currentPiIterations |
		Where-Object {$currentDate -le (ConvertTo-Date $_.attributes.startDate).ToUniversalTime().Date -and $_.attributes.timeframe -eq 'future'};
	if (($null -ne $futurePiIterations) -and ($futurePiIterations.Count -ne 0))
	{
		# next sprint is in the current PI
		$nextPiIteration = $futurePiIterations[0];
		$iterationName = $nextPiIteration.name;
	}
	else
	{
		# next sprint is in the next PI
		[string]$nextPi = [int]($sprintNameParts[1]) + 1;
		$sprintNameParts[1] = $nextPi;
		[array]$futurePiIterations = Get-AllPiIterations $sprintNameParts $orgUrl $ProjectName $Team $authHeader |
			Sort-Object -Property @{Expression = {$_.attributes.startDate}};
		if ($null -eq $futurePiIterations -or $futurePiIterations.Count -eq 0)
		{
			$message = "PI {0} has no defined sprint dates." -f $sprintNameParts[1];
			Stop-ProcessError $message;
		}
		$nextPiIteration = $futurePiIterations[0];
		$iterationName = $nextPiIteration.name;
	}
	$sprintNameParts = Get-SprintNameParts $iterationName;
	$piNumber = $sprintNameParts[1];
	$sprintNumber = $sprintNameParts[3];
	$testSprintNumber = $sprintNumber;
	$iterationStartDate = (ConvertTo-Date $nextPiIteration.attributes.startDate).ToUniversalTime().Date;
	$iterationEndDate = (ConvertTo-Date $nextPiIteration.attributes.finishDate).ToUniversalTime().Date;
	$currentDate = $iterationStartDate;
	Write-Output ("Current date: {0} from iteration '{1}'," -f $currentDate,$iterationName);
}
Write-Output ("Current Date: {0}, Iteration End Date: {1}" -f $currentDate,$iterationEndDate);
if ($sprintNameParts[2] -eq "IP")
{
	$currentPiIterations = Get-AllPiIterations $sprintNameParts $orgUrl $ProjectName $Team $authHeader;
	$ipSprintNumber = $currentPiIterations.Count;
	Write-Verbose "Current IP sprint is Sprint: $ipSprintNumber";
	$sprintNumber = $ipSprintNumber.ToString();
	$testSprintNumber = $sprintNameParts[2];
}
$excludeThisSprint = $excludedSprints.Contains($testSprintNumber);
Write-Output "excludeThisSprint: $excludeThisSprint";
$currentSprint = "{0}.{1}" -f $piNumber,$sprintNumber;
if ([string]::IsNullOrWhiteSpace($branchName))
{
	$branchName = "PI{0}.{1}" -f $piNumber,($sprintNumber-1);
}
else
{
	Write-Output ("Using override branch name: '{0}'." -f $branchName);
}
$sprintStartDate = $iterationStartDate.ToUniversalTime().ToShortDateString();
$sprintEndDate = $iterationEndDate.ToUniversalTime().ToShortDateString();
Write-Output ("Iteration period for {0}({1}): {2} to {3}" -f $iterationName,$currentSprint,$sprintStartDate,$sprintEndDate);
$isStartOfSprint = 'false';
$isStartOfRelease = 'false';
if ($currentDate -eq $iterationStartDate)
{
	$isStartOfSprint = 'true';
}
if (![string]::IsNullOrWhiteSpace($overrideStartDate))
{
	$iterationStartDate = (ConvertTo-Date $overrideStartDate).ToUniversalTime().Date;
	Write-Output ("Using override start date of '{0}'" -f $iterationStartDate.ToUniversalTime().ToShortDateString());
}
if (($currentDate -eq $iterationStartDate) -and 
		((-not $excludeThisSprint) -or ($currentSprint -eq $overriderStartSprint)))
{
	$isStartOfRelease = 'true';
}
Write-Output "CurrentSprint: '$currentSprint'";
Write-Output "SprintStartDate: '$sprintStartDate'";
Write-Output "IsStartOfSprint: '$isStartOfSprint'";
Write-Output "IsStartOfRelease: '$isStartOfRelease'";
Write-Output "BranchName: '$branchName'";
Write-Output "The following create or update pipeline variables.";
Write-Output ("##vso[task.setvariable variable=CurrentSprint;]$currentSprint");
Write-Output ("##vso[task.setvariable variable=SprintStartDate;]$sprintStartDate");
Write-Output ("##vso[task.setvariable variable=IsStartOfSprint;]$isStartOfSprint");
Write-Output ("##vso[task.setvariable variable=IsStartOfRelease;]$isStartOfRelease");
Write-Output ("##vso[task.setvariable variable=BranchName;]$branchName");
