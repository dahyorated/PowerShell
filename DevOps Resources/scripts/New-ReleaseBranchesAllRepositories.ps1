<#
.Synopsis
Create a release branch in all repositories.

.Description
The New-ReleaseBranchesAllRepositories script creates the release -BranchName branch in the repositories specified by -ControlFile.

.Parameter BranchName
This is the name of the release branch to create.

.Parameter ControlFile
This is the JSON file contain information on all of the repositories to be included in the create operation.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[ValidatePattern('^PI[0-9]+\.[0-9]+$')]
	[string]$BranchName = 'PI99.99',
	[Parameter(Mandatory=$false)]
	[string]$ControlFile = "ReleaseRepositories.json"
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$controlInformation = Get-Content "$PSScriptRoot\$ControlFile" | ConvertFrom-Json;
$count = $controlInformation.repositories.Count;
$repositories = $controlInformation.repositories;
for ($i = 0; $i -lt $count; $i++)
{
	$repositoryName = $repositories[$i];
	Write-Output "Processing '$repositoryName'.";
	if ($PSCmdlet.ShouldProcess($repositoryName))
	{
		. $PSScriptRoot\New-ReleaseBranch -BranchName $BranchName -RepositoryName $repositoryName;
	}
}
