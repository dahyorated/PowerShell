<#
.SYNOPSIS
Get the current IAC variable group settings into a spreadsheet.

.DESCRIPTION
This gets the current IAC variable group settings into a spreadsheet named -OutFile "IAC-Settings.xslx".

.PARAMETER OutFile
This is the name of the generated spreadsheet.

.PARAMETER IacFiles
This is the set of filenames for the IAC variable groups.

.PARAMETER Prefix
This is the prefix for the variable group JSON files.

.PARAMETER NoExcel
This switch prevents the creation of the spreadsheet.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$OutFile = "$PWD\IAC-Settings.xlsx",
	[Parameter(Mandatory=$False)]
	[string]$Folder = "$PWD\VariableGroups",
	[Parameter(Mandatory=$False)]
	[string]$Prefix = "iacvariables-",
	[Parameter(Mandatory=$False)]
	[string[]]$IacFiles = @("euwdev","euwqa","euwuat","euwperf","euwdemo","euwstage","euwprod","usedev","usestage","useprod")
)

Function New-IacSetting
{
	param(
		[string]$stageName
	)
	return [PSCustomObject]@{
		StageName = $stageName
		clientid = ''
		spnName = ''
		configUrl = ''
		keyvault = ''
		resourcegroup = ''
		resourcegrouptenant = ''
		serviceConnection = ''
		subscriptionid = ''
		tenantid = ''
		user = ''
	};
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$xlsx = New-Object System.Collections.ArrayList;
foreach ($iacFile in $IacFiles)
{
	$jsonFile = "{0}\{1}{2}.json" -f $Folder,$Prefix,$iacFile;
	$iacContent = (Get-Content $jsonFile | ConvertFrom-Json);
	$iacVariables = $iacContent.variables;
	$nextRow = New-IacSetting $iacVariables.StageName.value;
	$nextRow.clientid = $iacVariables.clientid.value;
	$spn = Get-AzADServicePrincipal -ApplicationId $iacVariables.clientid.value;
	$nextRow.spnName = $spn.DisplayName;
	$nextRow.configUrl = $iacVariables.configUrl.value;
	$nextRow.clientid = $iacVariables.clientid.value;
	$nextRow.keyvault = $iacVariables.keyvault.value;
	$nextRow.resourcegroup = $iacVariables.resourcegroup.value;
	$nextRow.resourcegrouptenant = $iacVariables.resourcegrouptenant.value;
	$nextRow.serviceConnection = $iacVariables.serviceConnection.value;
	$nextRow.subscriptionid = $iacVariables.subscriptionid.value;
	$nextRow.tenantid = $iacVariables.tenantid.value;
	$nextRow.user = $iacVariables.user.value;
	$newIndex = $xlsx.Add($nextRow);
	if ($isVerbose)
	{
		Write-Output ("Added row {0} for {1}" -f $newIndex,$iacVariables.StageName.value);
	}
}
if ($isVerbose)
{
	$xlsx;
}
Import-Module ImportExcel;
Remove-Item -Path $OutFile -ErrorAction Ignore;
$excelParams = @{
	Path = $OutFile
	Show = $true
	TableName = "IAC_Settings"
	AutoSize = $true
	FreezeTopRow = $true
};
$xlsx |
	Sort-Object StageName |
	Export-Excel @excelParams;
