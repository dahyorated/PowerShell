<#
.Synopsis
Lock or unlock a branch in all repositories.

.Description
The Lock-BranchesAllRepositories script locks or unlocks the -BranchName branch in the repositories specified by -ControlFile.

.Parameter BranchName
This is the name of the branch to lock or unlock.

.Parameter ControlFile
This is the JSON file contain information on all of the repositories to be included in the lock or unlock operation.

.Parameter Unlock
This specifies that the script should unlock the -BranchName branch (instead of locking the -BranchName branch).

.Example
Lock-BranchesAllRepositories -BranchName 'Release/PI9.5';

This will lock the Release/PI9.5 branch in all repositories contained in the "ReleaseRepositories.json" control file.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[string]$BranchName = 'develop',
	[Parameter(Mandatory=$false)]
	[string]$ControlFile = "ReleaseRepositories.json",
	[switch]$Unlock
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$controlInformation = Get-Content "$PSScriptRoot\$ControlFile" | ConvertFrom-Json;
$count = $controlInformation.repositories.Count;
$repositories = $controlInformation.repositories;
Write-Output ("Processing {0} repositories." -f $count);
for ($repoIndex = 0; $repoIndex -lt $count; $repoIndex++)
{
	$repositoryName = $repositories[$repoIndex];
	Write-Output "Processing '$repositoryName'.";
	if ($PSCmdlet.ShouldProcess($repositoryName))
	{
		. $PSScriptRoot\Lock-Branch -BranchName $BranchName -RepositoryName $repositoryName -Unlock:$Unlock;
	}
}
