<#
.Synopsis
Set the pipeline variables used by the "Deploy Function App with Connection String" task group.

.Description
The Set-FunctionAppSettings script sets the pipeline variable used by the "Deploy Function App with Connection String" task group.
- appSettingsJson
- connectionStrings
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)]
	[string]$DelimitedAppSettings,
	[Parameter(Mandatory=$true)]
	[string]$DelimitedConnectionStrings
)
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$appSettingFormat = '{"name": "<<0>>", "value": "<<1>>", "slotSetting": <<2>>}';
$connectionStringFormat = '{"name": "<<0>>","value": "<<1>>", "type": "<<2>>", "slotSetting": <<3>>}';
if ($isVerbose)
{
	Write-NameAndValue -Name "Inputs"
	Write-NameAndValue -Name "==> DelimitedAppSettings" -Value $DelimitedAppSettings;
	Write-NameAndValue -Name "==>DelimitedConnectionStrings" -Value $DelimitedConnectionStrings;
	Write-Output "`n";
}
$appSettingsJson = ConvertTo-JsonArray -SetData $DelimitedAppSettings -SetFormat $appSettingFormat;
Write-Output ("##vso[task.setvariable variable=appSettingsJson;]$appSettingsJson");
$connectionStrings = ConvertTo-JsonArray -SetData $DelimitedConnectionStrings -SetFormat $connectionStringFormat;
Write-Output ("##vso[task.setvariable variable=connectionStrings;]$connectionStrings");
