<#
.Synopsis
Remove unneeded release from all CTP folders.

.Description
The Remove-AllUnneededReleases script removed unneeded release from all CTP folders.

.Parameter ControlFile
This JSON file specifies all of the definition folders to be processed.

.PARAMETER Force
This forces the -JsonFile file to recreated using all current and previous releases.

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
	[switch]$Force,
	[switch]$ReleaseOnly
)

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$control = ConvertFrom-Json -InputObject ([string](Get-Content $ControlFile));
[array]$queryPaths = @();
if ($Force)
{
	$control.sources |
		Where-Object sourceType -eq "ReleaseDefinition" |
		Foreach-Object {
		$queryPaths += "{0}\*" -f $_.sourcePath;
		};
}
elseif ($ReleaseOnly)
{
	$currentPath = "{0}\*" -f $control.currentReleaseDefinition;
	[array]$queryPaths = @($currentPath)
}
else
{
	$control.sources |
		Where-Object {($_.sourceType -eq "ReleaseDefinition") -and $_.isActive} |
		Foreach-Object {
		$queryPaths += "{0}\*" -f $_.sourcePath;
		};
};

. $PSScriptRoot\Remove-UnneededReleases -ReleaseDefinitions $queryPaths;
