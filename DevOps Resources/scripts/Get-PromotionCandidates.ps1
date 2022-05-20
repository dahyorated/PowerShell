[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonFile = "$pwd\ReleaseDefinitionStatus.json",
	[Parameter(Mandatory=$False)]
	[string]$SourceStage = 'UAT',
	[Parameter(Mandatory=$False)]
	[string]$TargetStage = 'STG',
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Pending promotions from '$SourceStage' to '$TargetStage'.";
$SourceStage = $SourceStage.ToLower();
$TargetStage = $TargetStage.ToLower();
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$rdStatuses = Get-Content -Path $jsonFile | ConvertFrom-Json;
$rdStatuses | 
	Sort-Object definitionName |
	ForEach-Object {
		$relDefName = $_.definitionName;
		$target = $_.$TargetStage;
		$source = $_.$SourceStage;
		$targetBuildId = $target.BuildId;
		$sourceBuildId = $source.BuildId;
		if ($sourceBuildId -gt $targetBuildId)
		{
			Write-Output "$($relDefName): $($source.ReleaseName)";
		}
	}
;
