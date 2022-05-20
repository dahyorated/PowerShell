[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)]
	[string]$developVersionName = "Develop",
	[Parameter(Mandatory=$False)]
	[string]$hotfixVersionName = "Hotfix",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$Team = "DevOps"
)

Function Get-CurrentIterationVersion
{
	param (
	)
	$currentIteration = Get-CurrentIteration $orgUrl $ProjectName $Team $authHeader;
	$iterationName = $currentIteration.name;
	$sprintNameParts = Get-SprintNameParts $iterationName;
	$script:majorVersion = $sprintNameParts[1];
	$script:minorVersion = $sprintNameParts[3];
	# BEGIN fake IP sprint
	#$script:minorVersion = "IP";
	# END fake IP sprint
	if ($minorVersion -eq "IP")
	{
		$currentPiIterations = Get-AllPiIterations $sprintNameParts $orgUrl $ProjectName $Team $authHeader;
		$script:minorVersion = $currentPiIterations.Count.ToString();
		$ipSprint = $currentPiIterations.Count;
		Write-Verbose "Current IP sprint is Sprint: $ipSprint";
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "token = $token";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
Get-CurrentIterationVersion;
Write-Output "Version: $($majorVersion).$($minorVersion)";
