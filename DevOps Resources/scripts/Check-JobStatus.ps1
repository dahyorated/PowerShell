[CmdletBinding()]
param (
	[Parameter(Mandatory = $true)]
	[int]$JobId
)
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$global:jobMsg = Wait-JobCompletion $JobId -skipFirstSleep -noExit;
Write-Host $jobMsg | ConvertTo-Json -Depth 100;
