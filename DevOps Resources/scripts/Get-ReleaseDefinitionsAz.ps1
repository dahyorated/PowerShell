[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$DestinationFolder = ".\CTP"
)
Import-Module -Name .\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Verbose: $isVerbose";
$org = "https://eyglobaltaxplatform.visualstudio.com/";
$project = "Global Tax Platform";
$query = "[?path=='\CTP']";
$global:rdCtp = ConvertFrom-Json ([string](az pipelines release definition list --top 1000 --query $query --organization $org --project $project));
for ($i = 0; $i -lt $rdCtp.Count; $i++)
{
	$rd = $rdCtp[$i];
	$rdId = $rd.id;
	$rdName = $rd.name;
	$rdPath = $rd.path;
	$rdRevision = $rd.revision;
	$rootFilename = "{0}\{1}" -f $DestinationFolder,$rdName;
	$jsonFilename = "$rootFilename.json";
	$ymlFilename = "$rootFilename.yml";
	if (Test-Path $jsonFilename)
	{
		# already exists
		$rdOld = ConvertFrom-Json ([string](Get-Content $jsonFilename));
		if ($rdOld.revision -eq $rdRevision)
		{
			Write-Output "Release definition pipeline '$($rdPath)\$($rdName)[$($rdId)]' has not changed.";
			continue;
		}
	}
	Write-Output "Release definition pipeline '$($rdPath)\$($rdName)[$($rdId)]' saved in '$($DestinationFolder)'.";
	az pipelines release definition show --id $rdId -o json --organization $org --project $project | Out-File $jsonFilename;
	az pipelines release definition show --id $rdId -o yaml --organization $org --project $project | Out-File $ymlFilename;
}
