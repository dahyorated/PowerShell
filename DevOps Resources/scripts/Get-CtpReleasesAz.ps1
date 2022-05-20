[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$DestinationFolder = ".\CTP\"
)
Import-Module -Name .\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Verbose: $isVerbose";
$org = "https://eyglobaltaxplatform.visualstudio.com/";
$project = "Global Tax Platform";
$query = "[?releaseDefinition.path=='\CTP']";
$global:rCtp = ConvertFrom-Json ([string](az pipelines release list --top 10000 --query "$query" --organization $org --project $project));
Write-Output $rCtp.Count;
if ($isVerbose)
{
	$rCtp | Format-Table -AutoSize;
}
$global:rCtpSorted = ($rCtp |
	Select-Object -Property @{Name='DefinitionName';Expression={$_.releaseDefinition.name}},name,id,status,@{Name='DefinitionId';Expression={$_.releaseDefinition.id}},@{Name='Path';Expression={$_.releaseDefinition.path}} |
	Sort-Object -Property @{Expression = "DefinitionName"; Descending = $False},@{Expression = "id"; Descending = $True});
$rCtpSorted | Format-Table -AutoSize;
#for ($i = 0; $i -lt $rCtp.Count; $i++)
#{
#	$rd = $rCtp[$i];
#	$rdRevision = $rd.revision;
#	$rootFilename = "{0}\{1}" -f $DestinationFolder,$rd.name;
#	$jsonFilename = "$rootFilename.json";
#	$ymlFilename = "$rootFilename.yml";
#	if (Test-Path $jsonFilename)
#	{
#		# already exists
#		$rdOld = ConvertFrom-Json ([string](Get-Content $jsonFilename));
#		if ($rdOld.revision -eq $rdRevision)
#		{
#			Write-Output "Release definition pipeline '$($rd.path)\$($rd.name)[$($rd.id)]' has not changed.";
#			continue;
#		}
#	}
#	Write-Output "Release definition pipeline '$($rd.path)\$($rd.name)[$($rd.id)]' saved in '$($DestinationFolder)'.";
#	$releaseDefinitionId = $rCtp[$i].id;
#	az pipelines release definition show --organization $org --project $project --id $releaseDefinitionId -o json |
#		Out-File $jsonFilename;
#	az pipelines release definition show --organization $org --project $project --id $releaseDefinitionId -o yaml |
#		Out-File $ymlFilename;
#}
