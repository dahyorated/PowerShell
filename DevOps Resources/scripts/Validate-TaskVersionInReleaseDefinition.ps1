<#
.Synopsis
Validate the usage of a specified version for a task ID.

.Description
The Validate-TaskVersionInReleaseDefinition script validate the usage of the -Version for the -TaskId.

A message is output for each -TaskId task that does not have the correct -Version.

.Parameter DefinitonToValidate
This is the absolute or relative path to the release definition JOSN file to be validated.

.Parameter TaskId
This is the task ID for the task to be validated.

.Parameter Version
This is the desired version.

.Outputs
The output is information like the following.

Checking '.\BoardwalkService-ctp-R9.5.json' for Task ID 72a1931b-effb-4d2e-8fd8-f8472a07cb62 with version other than 3.*
Stage usestage-BwClient01003[Phase Agent job(Task Azure PowerShell script: InlineScript)]: 2.*
Found 1 matches in 68 stages, 68 phases, and 488 tasks.

.Example
Validate-TaskVersionInReleaseDefinition -DefinitonToValidate '.\BoardwalkService-ctp-R9.5.json' -TaskId '72a1931b-effb-4d2e-8fd8-f8472a07cb62' -Version '3.*';

This outputs a message for each task with a taskId of '72a1931b-effb-4d2e-8fd8-f8472a07cb62' that is not version '3.*'.
#>
[CmdletBinding()]
param(
	[string]$DefinitonToValidate = 'C:\EYdev\devops\pipelines\ReleaseDefinitions\CTP\Release 9.5\BoardwalkService-ctp-R9.5.json',
	[string]$TaskId = '72a1931b-effb-4d2e-8fd8-f8472a07cb62',
	[string]$Version = '2.*'
)
Write-Output ("Checking '{0}' for Task ID {1} with version other than {2}" -f $DefinitonToValidate,$TaskId,$Version);
$relDef = Get-Content $DefinitonToValidate | ConvertFrom-Json;
$stages = 0;
$phases = 0;
$tasks = 0;
$taskMatches = 0;
$relDef.environments | Foreach-Object `
{
	$stageName = $_.name;
	$stages++;
	$_.deployPhases | Foreach-Object `
	{
		$phaseName = $_.name;
		$phases++;
		$tasks += $_.workflowTasks.Count;
		$_.workflowTasks |
			Where-Object {$_.taskId -eq $TaskId -and $_.version -ne $Version} |
			Foreach-Object `
			{
				$taskName = $_.name;
				$taskMatches++;
				Write-Output ("Stage {0}[Phase {1}(Task {2})]: {3}" -f $stageName,$phaseName,$taskName,$_.version);
			}
	}
}
Write-Output ("Found {0} matches in {1} stages, {2} phases, and {3} tasks." -f $taskMatches,$stages,$phases,$tasks);
