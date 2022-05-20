<#
.Synopsis
Create a versioning variable group for a build pipeline.

.Description
The New-VariableGroupForBuildPipeline script creates a versioning variable group for the -CiName build pipeline.

.Parameter CiName
This is the complete name of the build pipeline.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Team
This is a team for which the sprints are defined.

.Example
New-VariableGroupForBuildPipeline -CiName 'Logging Database - CI';

This creates the Versioning_LoggingDatabase' variable group to manage versioning for 'Logging Database - CI'.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$CiName = "Test3 - CI",
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps"
)
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = (Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId).TrimEnd("/");
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
$simpleName = $CiName.Replace(" ","").TrimEnd("CI").TrimEnd("-");
$groupName = "Versioning_{0}" -f $simpleName;
$releases = Get-Content "$PSScriptRoot\Template-MajorMinorVersionOther.json" | ConvertFrom-Json | ConvertTo-Json -Depth 100 -Compress;
$releases = $releases -replace '"','\"';
$newVgJson = '{"variables": {"Develop": {"value": "1.1.0.0"},"Releases": {"value": "#RS#"}},"type": "Vsts","name": "#GP#"}';
$newVgJson = $newVgJson -replace "#GP#",$groupName;
$newVgJson = $newVgJson -replace "#RS#",$releases;
$newVg =$newVgJson | ConvertFrom-Json;
$updatedVariableGroup = New-VariableGroup $newVg $tfsBaseUrl $ProjectName $authHeader;
Write-Verbose ($updatedVariableGroup | ConvertTo-Json -Depth 100 -Compress);
