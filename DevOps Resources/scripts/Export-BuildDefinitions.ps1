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
	[string]$SourcePaths = "\\CTP",
	[switch]$IncludeYaml
)
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
#$query = "[?path=='{0}']" -f $SourcePath;
$sourcePath = $SourcePaths.Split("|");
for ($i = 0; $i -lt $sourcePath.Count; $i++)
{
	$rootPathname = Remove-EndsWith ("{0}\BuildDefinitions{1}" -f $RepositoryRootFolder,$sourcePath[$i]) "\";
	if (!(Test-Path $rootPathname))
	{
		Write-Output "Creating folder '$rootPathname'.";
		mkdir $rootPathname;
	}
}
$bds = ConvertFrom-Json ([string](az pipelines build definition list --top 1000 --organization $org --project $project));

$bdsCount = $bds.Count;
Write-Verbose "Processing $($bdsCount) build definitions.";
$changes = 0;
$skipped = 0;
for ($i = 0; $i -lt $bdsCount; $i++)
{
	$bd = $bds[$i];
	$bdId = $bd.id;
	$bdName = $bd.name;
	$bdPath = $bd.path;
	if (!$sourcePath.Contains($bdPath))
	{
		Write-Verbose "Skipping '$($bdPath)'."
		$skipped++;
		continue;
	}
	$rootPathname = Remove-EndsWith ("{0}\BuildDefinitions{1}" -f $RepositoryRootFolder,$bdPath) "\";
	if ($bdPath -eq "\")
	{
		$bdPath = "";
	}
	$bdRevision = $bd.revision;
	$bdFullname = "$($bdPath)\$($bdName)[$($bdId)]";
	$rootPathnameWithoutExtension = "{0}\{1}" -f $rootPathname,$bdName;
	$jsonFilename = "$rootPathnameWithoutExtension.json";
	$ymlFilename = "$rootPathnameWithoutExtension.yml";
	$isDraft = [bool]($null -ne $bd.draftOf);
	if ($isDraft)
	{
		$bdDraftOfId = $bd.draftOf.id;
		Write-Warning "Ignoring build definition pipeline '$($bdFullname)' which is a draft of '...[$($bdDraftOfId)]'.";
		$skipped++;
		continue;
	}
	if (Test-Path $jsonFilename)
	{
		# already exists
		$bdOld = ConvertFrom-Json ([string](Get-Content $jsonFilename));
		if ($bdOld.revision -eq $bdRevision)
		{
			Write-Verbose "Build definition pipeline '$($bdFullname)' has not changed.";
			continue;
		}
	}
	$changes++;
	Write-Output "Build definition pipeline '$($bdFullname)' saved in '$($RepositoryRootFolder)'.";
	az pipelines build definition show --id $bdId -o json --organization $org --project $project | Out-File $jsonFilename;
	if ($IncludeYaml)
	{
		az pipelines build definition show --id $bdId -o yaml --organization $org --project $project | Out-File $ymlFilename;
	}
}
$processed = $bdsCount - $skipped;
$message = "Updated $($changes) of $($processed) build definitions in '$SourcePaths'.";
Write-Verbose $message;
$global:ExportSummary += $message;
