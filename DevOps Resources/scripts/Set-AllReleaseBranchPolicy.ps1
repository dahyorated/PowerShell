<#
.Synopsis
Set the branch policies in all repositories.

.Description
The Set-AllReleaseBranchPolicy script sets the -BranchName branch policies in the repositories specified by -ControlFile.

.Parameter BranchName
This is the name of the branch to lock or unlock.

.Parameter ControlFile
This is the JSON file contain information on all of the repositories to be included in the lock or unlock operation.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[string]$BranchName = 'Test',
	[Parameter(Mandatory=$false)]
	[string]$ControlFile = "ReleaseRepositories.json"
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
		. $PSScriptRoot\Set-ReleaseBranchPolicy -BranchName $BranchName -RepositoryName $repositoryName;
	}
}
