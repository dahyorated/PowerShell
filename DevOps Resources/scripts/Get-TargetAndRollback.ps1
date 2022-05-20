<#
.Synopsis
Create an Excel spreadsheet with the releases targeted for PRD and the rollback releases.

.Description
This creates an Excel spreadsheet with the releases targeted for PRD and the rollback releases.
- The spreadsheet contains one row per targeted release definition.
- Each row contains the release definition name, the targeted release name, and the rollback release name.
- The -JsonFile file is the source of information on what is currently deployed.

.Parameter Release
This is the release in the form "9.9".

.Parameter Hotfix
This is the hot fix version.
- A hot fix version is always a number greater than 0.
- The base release uses hot fix version 0.

.Parameter JsonFile
This is the name of the JSON file containing the release definition status.

.Parameter Exclusions
This is the JSON file containing the release definitions to exclude from consideration.

.Parameter UatPhase
This specifies that deployments in UAT should be used instead of those in STG.

.Parameter NoPublish
This skips the copy of the spreadsheet to the deployment folder for -Release.

.Inputs
None.

.Outputs
The output is an Excel spreadsheet named "Release {Release} Target And Rollback.xlsx" where {Release} is the value from -Release and -HotFix.
If -UatPhase is specified, the filename has a suffix of " - STG" (i.e., "Release {Release} Target And Rollback - STG.xlsx").

.Example
Get-TargetAndRollback -Release "9.1";

This gets the information based on the 9.1 releases currently deployed to STG and publishes the Release 9.1 spreadsheet to the 9.1 deployment folder.

.Example
Get-TargetAndRollback -Release "9.1" -Hotfix 2;

This gets the information based on the 9.1 releases currently deployed to STG and publishes the Release 9.1.2 spreadsheet to the 9.1 deployment folder.

.Example
Get-TargetAndRollback -UatPhase -Release "9.2";

This gets the information based on the 9.2 releases currently deployed to UAT and publishes the spreadsheet to the deployment folder.

.Example
Get-TargetAndRollback -Release "9.2" -NoPublish;

This get the information based on the 9.2 releases currently deployed to STG. It does not publish the spreadsheet to the deployment folder

#>
[CmdletBinding()]
param(

	[Parameter(Mandatory=$true)]
	[string]$Release,
	[Parameter(Mandatory=$false)]
	[ValidateRange(0,99)]
	[int]$Hotfix = 0,
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonFile = "$pwd\ReleaseDefinitionStatus.json",
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$Exclusions = "$pwd\ReleaseExclusions.json",
	[switch]$UatPhase,
	[switch]$NoPublish
)

Function New-Definition
{
	[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="None")]
	param(
		[string]$name,
		[string]$target,
		[string]$buildDefinition,
		[string]$buildName,
		[string]$rollback,
		[string]$relUrl
	)
	if ($PSCmdlet.ShouldProcess("Should not happen?")) {};
	return [PSCustomObject]@{
		ReleaseName = $name;
		PlannedRelease = $target;
		RollbackRelease = $rollback;
		Version = $buildName;
		BuildName = $buildDefinition;
		Notes = "";
		Comments = "";
		Status = "";
		ReleaseUrl = $relUrl;
	};
}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$releaseUrlFormat = "https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_releaseProgress?releaseId={0}";
$rds = Get-Content $JsonFile | ConvertFrom-Json;
$excluded = Get-Content $Exclusions | ConvertFrom-Json;
$xlsx = New-Object System.Collections.ArrayList;
$rds |
	Where-Object {(($_.definitionName -like '*-ctp') -or ($_.definitionName -like '*(ctp)')) -and (-not ($excluded -contains $_.definitionName)) } |
	Sort-Object definitionName |
	ForEach-Object {
		$name = $_.definitionName;
		$buildDefinition = $_.buildDefinitionName;
		if ($UatPhase)
		{
			$sourceStage = "uat";
		}
		else
		{
			$sourceStage = "stg";
		}
		$target = $_.$sourceStage.ReleaseName;
		$releaseId = $_.$sourceStage.ReleaseId;
		$buildName = $_.$sourceStage.BuildName;
		$rollBack = $_.prd.ReleaseName;
		$relUrl = $releaseUrlFormat -f $releaseId;
		if (($target -ne 'NA') -and ($target -ne $rollBack))
		{
			$newDefinition = New-Definition -name $name -target $target -buildDefinition $buildDefinition -buildName $buildName -rollback $rollBack -relUrl $relUrl;
			if ($_.prf.ReleaseName -ne $target)
			{
				$newDefinition.Comments = "Not in PRF";
			}
			$index = $xlsx.Add($newDefinition);
			Write-Verbose "Added $newDefinition.ReleaseName($index)";
		}
	}
;
if ($Hotfix -ne 0)
{
	$fileVersion = "{0}.{1}" -f $Release,$Hotfix;
}
else
{
	$fileVersion = $Release;
}
if ($xlsx.Count -eq 0)
{
	Write-Output ("No matches for Release {0}" -f $fileVersion);
	Exit;
}
if ($UatPhase)
{
	$filenameSuffix = " - STG";
}
else
{
	$filenameSuffix = "";
}
$xslxFile = "Release {0} Target And Rollback{1}.xlsx" -f $fileVersion,$filenameSuffix;
$excelParams = @{
	Path = $xslxFile
	Show = $true
	TableName = "ReleaseTarget"
	AutoSize = $true
	FreezeTopRow = $true
};
Import-Module ImportExcel;
Remove-Item -Path $xslxFile -ErrorAction Ignore;
$sprintParts = $Release -split "\.";
$niPrf = New-ConditionalText -Text "Not in PRF" -ConditionalTextColor White -BackgroundColor Red -Range "F:F";
$noRollBack = New-ConditionalText -Text "NA" -ConditionalTextColor Green -BackgroundColor Yellow -Range "C:C"
$xlsx |
	Sort-Object ReleaseName |
	Export-Excel @excelParams -ConditionalText $niPrf,$noRollBack;
$package = Open-ExcelPackage -Path $xslxFile -KillExcel;
$condition1 = '=IFERROR(FIND("{0}",B2),0)<>0' -f $Release;
$condition2 = '=IFERROR(FIND("R{0}.",B2),0)<>0' -f $sprintParts[0];
$range = "A2:A{0}" -f ($xlsx.Count+1);
$sheet = $package.Workbook.WorkSheets["sheet1"];
$sheet.Name = "Status at {0}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm UTC");
Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue $condition1 -ForegroundColor White -BackgroundColor Green -StopIfTrue;
Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue $condition2 -ForegroundColor Yellow -BackgroundColor Blue -StopIfTrue;
Close-ExcelPackage -ExcelPackage $package -Show;
if (-not $NoPublish)
{
	$deploymentFolder = "{0}\EY\Global Tax Platform - Releases\Deployment\PI{1}\Release {2}" -f $HOME,$sprintParts[0],$Release;
	Write-Output ("Publishing '{0}' to '{1}" -f $xslxFile,$deploymentFolder);
	Copy-Item -Path $xslxFile -Destination $deploymentFolder -Force;
}
