<#
.SYNOPSIS
Creates or updates the "ReleaseDefinitionStatus.json" file.

.DESCRIPTION
This creates or updates the "ReleaseDefinitionStatus.json" file.
The file is created if it does not exist or the -Force switch is used.
The SharePoint Excel file (local synced copy) is opened unless the -NoExcel switch is used.

If a new pipeline is added to the CTP folder or a pipeline is renamed, the -Force switch must be used to prevent errors.

.PARAMETER JsonFile
This is the JSON file that contains the results of a previous use of this script.
The name is determined by Get-ReleaseDefinitionStatus.

.Parameter ControlFile
This JSON file specifies all of the definition folders to be processed.

.PARAMETER Force
This forces the -JsonFile file to recreated using all current and previous releases.

.PARAMETER NoExcel
This suppresses the launching of Excel.

.PARAMETER SkipRefresh
This skips updating the content of -JsonFile.

.Parameter ReleaseOnly
This only processes the current release.

.Parameter ShowApprovals
If specified, the approvers for each stage are shown.

.Outputs
The output is an Excel spreadsheet named "$HOME\EY\Global Tax Platform - Releases\ReleaseDefinitionStatus.xlsx".

.EXAMPLE
Get-ReleaseStatus;

This updates the "ReleaseDefinitionStatus.json" file and launches Excel.

.EXAMPLE
Get-ReleaseStatus -Force -NoExcel;

This recreates the "ReleaseDefinitionStatus.json" file and does not launch Excel.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonFile = "$pwd\ReleaseDefinitionStatus.json",
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path -Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$ControlFile = "$PSScriptRoot\Export-AllDefinitions.json",
	[switch]$Force,
	[switch]$NoExcel,
	[switch]$SkipRefresh,
	[switch]$ReleaseOnly,
	[switch]$ShowApprovals
)

Function Get-NewRow
{
	param(
		[PsCustomObject]$rd
	)
	return [PSCustomObject]@{
		Release_Def_Name = $rd.definitionName
		Build_Def_Name = $rd.buildDefinitionName
		PRD_ReleaseName = $rd.prd.ReleaseName
		PRD_FinishedOn = ConvertTo-Date $rd.prd.FinishedOn
		PRD_BuildId = $rd.prd.BuildId
		PRD_Version = $rd.prd.BuildName
		STG_ReleaseName = $rd.stg.ReleaseName
		STG_FinishedOn = ConvertTo-Date $rd.stg.FinishedOn
		STG_BuildId = $rd.stg.BuildId
		STG_Version = $rd.stg.BuildName
		DMO_ReleaseName = $rd.dmo.ReleaseName
		DMO_FinishedOn = ConvertTo-Date $rd.dmo.FinishedOn
		DMO_BuildId = $rd.dmo.BuildId
		DMO_Version = $rd.dmo.BuildName
		PRF_ReleaseName = $rd.prf.ReleaseName
		PRF_FinishedOn = ConvertTo-Date $rd.prf.FinishedOn
		PRF_BuildId = $rd.prf.BuildId
		PRF_Version = $rd.prf.BuildName
		UAT_ReleaseName = $rd.uat.ReleaseName
		UAT_FinishedOn = ConvertTo-Date $rd.uat.FinishedOn
		UAT_BuildId = $rd.uat.BuildId
		UAT_Version = $rd.uat.BuildName
		QAT_ReleaseName = $rd.qat.ReleaseName
		QAT_FinishedOn = ConvertTo-Date $rd.qat.FinishedOn
		QAT_BuildId = $rd.qat.BuildId
		QAT_Version = $rd.qat.BuildName
		DEV_ReleaseName = $rd.dev.ReleaseName
		DEV_FinishedOn = ConvertTo-Date $rd.dev.FinishedOn
		DEV_BuildId = $rd.dev.BuildId
		DEV_Version = $rd.dev.BuildName
		PRDDR_ReleaseName = $rd.prdDr.ReleaseName
		PRDDR_FinishedOn = ConvertTo-Date $rd.prdDr.FinishedOn
		PRDDR_BuildId = $rd.prdDr.BuildId
		PRDDR_Version = $rd.prdDr.BuildName
		STGDR_ReleaseName = $rd.stgDr.ReleaseName
		STGDR_FinishedOn = ConvertTo-Date $rd.stgDr.FinishedOn
		STGDR_BuildId = $rd.stgDr.BuildId
		STGDR_Version = $rd.stgDr.BuildName
		DEVDR_ReleaseName = $rd.devDr.ReleaseName
		DEVDR_FinishedOn = ConvertTo-Date $rd.devDr.FinishedOn
		DEVDR_BuildId = $rd.devDr.BuildId
		DEVDR_Version = $rd.devDr.BuildName
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$control = ConvertFrom-Json -InputObject ([string](Get-Content $ControlFile));
$fileExists = Test-Path -Path $JsonFile -PathType Leaf;
[array]$queryPaths = @();
if ($Force -or (-not $fileExists))
{
	Remove-Item $JsonFile -ErrorAction Ignore;
	$control.sources |
		Where-Object {$_.sourceType -eq "ReleaseDefinition" -and $_.isReleasePipeline} |
		Foreach-Object {
		$queryPaths += $_.sourcePath;
		};
}
elseif ($ReleaseOnly)
{
	[array]$queryPaths = @($control.currentReleaseDefinition)
}
else
{
	$control.sources |
		Where-Object {($_.sourceType -eq "ReleaseDefinition") -and $_.isActive -and $_.isReleasePipeline} |
		Foreach-Object {
		$queryPaths += $_.sourcePath;
		};
};
if (-not $SkipRefresh)
{
	Get-ReleaseDefinitionStatus -QueryPaths $queryPaths -ShowApprovals:$ShowApprovals;
}
if (-not $NoExcel)
{
	#$xlsxFile = "$PWD\ReleaseDefinitionStatus-New.xlsx";
	$xlsxFile = "$HOME\EY\Global Tax Platform - Releases\ReleaseDefinitionStatus.xlsx";
	Write-Output "Excel spreadsheet will be saved in '$($xlsxFile)'.";
	Remove-Item $xlsxFile -ErrorAction Ignore;
	$excelParams = @{
		Path = "$xlsxFile"
		Show = $false
		TableName = "ReleaseStatus"
		AutoSize = $true
		FreezeTopRowFirstColumn = $true
	};
	Import-Module ImportExcel;
	$rds = (Get-Content $JsonFile) | ConvertFrom-Json;
	$global:rows = New-Object System.Collections.ArrayList;
	$rds |
		Sort-Object definitionName |
		ForEach-Object {
			$newRow = Get-NewRow $_;
			$index = $rows.Add($newRow);
			Write-Verbose ("Adding row[{0}] for" -f $index);
		};
	$lastRow = $rows.Count;
	$rangeFormat = "{0}2:{0}$($lastRow)";
	$excelPackage = $rows | Export-Excel -PassThru @excelParams;
	$sheet = $excelPackage.Workbook.WorkSheets["sheet1"];
	$sheet.Name = "Status at {0}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm UTC");
	# Fix BuildId column widths
	Set-ExcelRange -Worksheet $sheet -Range "E:E" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "I:I" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "M:M" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "Q:Q" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "U:U" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "Y:Y" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AC:AC" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AG:AG" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AK:AK" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AO:AO" -Width 14;
	# Fix BuildName column widths
	Set-ExcelRange -Worksheet $sheet -Range "F:F" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "J:J" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "N:N" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "R:R" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "V:V" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "Z:Z" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AD:AD" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AH:AH" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AL:AL" -Width 14;
	Set-ExcelRange -Worksheet $sheet -Range "AP:AP" -Width 14;
	# PRD
	$range = $rangeFormat -f "G";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=C2=G2' -ForegroundColor White -BackgroundColor Red -Bold -StopIfTrue;
	# STG
	$range = $rangeFormat -f "G";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=E2<I2' -ForegroundColor Yellow -BackgroundColor Blue -Bold -StopIfTrue;
	# DMO
	$range = $rangeFormat -f "K";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=AND(K2<>"NA",M2<U2)' -ForegroundColor Yellow -BackgroundColor Blue -Bold -StopIfTrue;
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=M2>U2' -ForegroundColor White -BackgroundColor Purple -Bold -StopIfTrue;
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=M2<U2' -ForegroundColor Red -BackgroundColor Yellow -Bold -StopIfTrue;
	# PRF
	$range = $rangeFormat -f "O";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=Q2>U2' -ForegroundColor White -BackgroundColor Purple -Bold -StopIfTrue;
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=Q2<U2' -ForegroundColor Red -BackgroundColor Yellow -Bold -StopIfTrue;
	# UAT
	$range = $rangeFormat -f "S";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=I2<U2' -ForegroundColor Yellow -BackgroundColor Blue -Bold -StopIfTrue;
	# QAT
	$range = $rangeFormat -f "W";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=U2<Y2' -ForegroundColor Yellow -BackgroundColor Blue -Bold -StopIfTrue;
	# DEV
	$range = $rangeFormat -f "AA";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=Y2<AC2' -ForegroundColor Yellow -BackgroundColor Blue -Bold -StopIfTrue;
	# PRD DR
	$range =$rangeFormat -f "AE";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=C2<>AE2' -ForegroundColor White -BackgroundColor Red -Bold -StopIfTrue;
	# STG DR
	$range =$rangeFormat -f "AI";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=G2<>AI2' -ForegroundColor White -BackgroundColor Red -Bold -StopIfTrue;
	# DEV DR
	$range =$rangeFormat -f "AM";
	Add-ConditionalFormatting -Worksheet $sheet -Address $range -RuleType Expression -ConditionValue '=AA2<>AM2' -ForegroundColor White -BackgroundColor Red -Bold -StopIfTrue;
	$legend = Open-ExcelPackage -Path "$($PSScriptRoot)\Legend.xlsx";
	$newLegend = Add-Worksheet -ExcelPackage $excelPackage -WorkSheetname "Legend" -MoveToEnd -CopySource $legend.Workbook.Worksheets["Legend"];
	if ($isVerbose)
	{
		Write-Output $newLegend;
	}
	Close-ExcelPackage -ExcelPackage $excelPackage;
};
