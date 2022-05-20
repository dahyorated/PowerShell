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
# Get all release definitions
$query = "[?path=='\CTP']";
$global:rdCtp = ConvertFrom-Json ([string](az pipelines release definition list --top 1000  --query $query --organization $org --project $project));
Write-Output "Found $($rdCtp.Count) release definitions";
if ($isVerbose)
{
	$global:rdCtp | Format-Table -AutoSize;
}
# Get all CTP release
$query = "[?releaseDefinition.path=='\CTP']";
$global:rCtp = ConvertFrom-Json ([string](az pipelines release list --top 10000 --query "$query" --organization $org --project $project));
ForEach ($rd in $rdCtp)
{
	$rdId = $rd.id;
	$rdName = $rd.name;
	$global:rr = [array]($rCtp | Where-Object -FilterScript {$_.releaseDefinition.id -eq $rdId});
	Write-Output "Found $($rr.Count) releases for $($rdName)";
	Add-Member -InputObject $rd -MemberType NoteProperty -Name 'releases' -Value $rr;
}
$cnt = 0;
$rdCtp | ForEach-Object {$cnt += $_.releases.Count};
Write-Output "Added $($cnt) releases";
