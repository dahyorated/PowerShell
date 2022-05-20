[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform"
)
Push-Location "C:\EYdev\devops\scripts";
Import-Module -Name .\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = (Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId).TrimEnd("/");
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
Get-Repository -RepositoryName 'BoardWalkRepo' -BaseUrl $tfsBaseUrl -TeamProject $teamProject -AuthHeader $authHeader;
Pop-Location;
