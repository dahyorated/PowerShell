[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path) )
		{
			throw "Folder '$_' does not exist.";
		}
		if(!($_ | Test-Path -PathType Container) )
		{
			throw "The RepositoryRootFolder argument must be a folder. Files are not allowed.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$RepositoryRootFolder = "C:\EYdev\Pipelines",
	[Parameter(Mandatory=$False)]
	[string]$SourcePath = "\\CTP",
	[switch]$IncludeYaml
)
Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
$query = "[?path=='{0}']" -f $SourcePath;
$rds = ConvertFrom-Json ([string](az pipelines release definition list --top 1000 --query $query --organization $org --project $project));
$rootPathname = Remove-EndsWith ("{0}\ReleaseDefinitions{1}" -f $RepositoryRootFolder,$SourcePath) "\";
if (!(Test-Path $rootPathname))
{
	Write-Output "Creating folder '$rootPathname'.";
	mkdir $rootPathname;
}
$rdsCount = $rds.Count;
Write-Verbose "Processing $($rdsCount) release definitions."
$changes = 0;
for ($i = 0; $i -lt $rdsCount; $i++)
{
	$rd = $rds[$i];
	$rdId = $rd.id;
	$rdName = $rd.name;
	$rdPath = $rd.path;
	if ($rdPath -eq "\")
	{
		$rdPath = "";
	}
	$rdRevision = $rd.revision;
	$rdFullname = "$($rdPath)\$($rdName)[$($rdId)]";
	$rootPathnameWithoutExtension = "{0}\{1}" -f $rootPathname,$rdName;
	$jsonFilename = "$rootPathnameWithoutExtension.json";
	$ymlFilename = "$rootPathnameWithoutExtension.yml";
	if (Test-Path $jsonFilename)
	{
		# already exists
		$rdOld = ConvertFrom-Json ([string](Get-Content $jsonFilename));
		if ($rdOld.revision -eq $rdRevision)
		{
			Write-Verbose "Release definition pipeline '$($rdFullname)]' has not changed.";
			continue;
		}
	}
	$changes++;
	Write-Output "Release definition pipeline '$($rdFullname)' saved in '$($RepositoryRootFolder)'.";
	az pipelines release definition show --id $rdId -o json --organization $org --project $project | Out-File $jsonFilename;
	if ($IncludeYaml)
	{
		az pipelines release definition show --id $rdId -o yaml --organization $org --project $project | Out-File $ymlFilename;
	}
}
$message = "Updated $($changes) of $($rdsCount) release definitions in '$SourcePath'.";
Write-Verbose $message;
$global:ExportSummary += $message;
