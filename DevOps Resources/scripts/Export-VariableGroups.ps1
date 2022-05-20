[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path) )
		{
			throw "Folder '$_' does not exist." 
		}
		if(!($_ | Test-Path -PathType Container) )
		{
			throw "The RepositoryRootFolder argument must be a folder. Files are not allowed."
		}
		return $true;
	})]
	[System.IO.FileInfo]$RepositoryRootFolder = "C:\EYdev\Pipelines",
	[switch]$IncludeYaml)
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$vgs = ConvertFrom-Json ([string](az pipelines variable-group list --top 1000 --organization $org --project $project));
$vgsCount = $vgs.Count;
$rootPathname = "{0}\VariableGroups" -f $RepositoryRootFolder;
if (!(Test-Path $rootPathname))
{
	Write-Output "Creating folder '$rootPathname'.";
	mkdir $rootPathname;
}
Write-Verbose "Processing $($vgsCount) variable groups."
$changes = 0;
for ($i = 0; $i -lt $vgsCount; $i++)
{
	$vg = $vgs[$i];
	$vgId = $vg.id;
	$vgName = $vg.name;
	$modifiedOn = $vg.modifiedOn;
	$rootPathnameWithoutExtension = "{0}\{1}" -f $rootPathname,$vgName;
	$jsonFilename = "$rootPathnameWithoutExtension.json";
	$ymlFilename = "$rootPathnameWithoutExtension.yml";
	if (Test-Path $jsonFilename)
	{
		# already exists
		$vgOld = ConvertFrom-Json ([string](Get-Content $jsonFilename));
		if ($vgOld.modifiedOn -eq $modifiedOn)
		{
			Write-Verbose "Variable group '$($vgPath)\$($vgName)[$($vgId)]' has not changed.";
			continue;
		}
	}
	$changes++;
	Write-Output "Variable group '$($vgPath)\$($vgName)[$($vgId)]' saved in '$($RepositoryRootFolder)'.";
	$vg | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFilename;
	if ($IncludeYaml)
	{
		$vg | ConvertTo-Yaml | Out-File -FilePath $ymlFilename;
	}
}
$message = "Updated $($changes) of $($vgsCount) variable groups.";
Write-Verbose $message;
$global:ExportSummary += $message;
