<#
.Synopsis
Exports all definitions except task groups.

.Description
The Export-AllDefinitions script exports all definitions that have changed except task groups.

.Parameter ControlFile
This JSON file specifies all of the definition folders to be processed.

.Parameter UpdateGit
If specified, the "devops" repository is updated with the new or changed definitions.

.Parameter RefreshAll
If specified, all definitions including inactive ones are exported if they have changed.

.Parameter ReleaseOnly
This only processes the current release.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path -Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$ControlFile = "$PSScriptRoot\Export-AllDefinitions.json",
	[switch]$UpdateGit,
	[switch]$RefreshAll,
	[switch]$ReleaseOnly
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$control = ConvertFrom-Json -InputObject ([string](Get-Content $ControlFile));
$repositoryRootFolder = $control.repositoryRootFolder;
$global:ExportSummary = @();
ForEach ($source in $control.sources)
{
	if ($RefreshAll -or ((-not $ReleaseOnly) -and $source.isActive) -or ($ReleaseOnly -and $control.currentReleaseDefinition -eq $source.sourcePath))
	{
		Write-Output "Processing $($source.sourceType)s in the '$($source.sourcePath)' folder.";
		switch ($source.sourceType) {
			"BuildDefinition"
				{
					. $PSScriptRoot\Export-BuildDefinitions -RepositoryRootFolder "$repositoryRootFolder" -SourcePaths $source.sourcePaths;
				}
			"ReleaseDefinition"
				{
					. $PSScriptRoot\Export-ReleaseDefinitions -RepositoryRootFolder "$repositoryRootFolder" -SourcePath $source.sourcePath;
				}
			"VariableGroup"
				{
					. $PSScriptRoot\Export-VariableGroups -RepositoryRootFolder "$repositoryRootFolder";
				}
			Default
			{
				Write-Error "'$($source.sourceType)' is an unsupported source type."
			}
		}
	}
}
if ($UpdateGit)
{
	$commitMessage = $ExportSummary -join "|";
	. $PSScriptRoot\Update-MasterBranch -CommitMessage "$commitMessage";
}
Write-Output "Export Summary:";
$ExportSummary;
