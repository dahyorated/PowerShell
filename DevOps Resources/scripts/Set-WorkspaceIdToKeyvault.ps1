<#
.Synopsis
Create Keyvault Entry for application insights 

.Description
This script will extract the instrument key for the specified Application Insights instance and check keyvault entry "appinsights-instrumentationkey"
	If it doesn't exist or have correct value it will set the secret

.Parameter kv
This is the name of the key vault for the environment.

.Parameter resourceGroupName
The Resource Group Name

.Parameter appInsightsName
If specified, the secret is updated even if it already exists in the -kv key vault.


.Example
Set-WorkspaceIdToKeyvault -kv "EUWDGTP005AKV01" -resourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -appInsightsName "EUWDGTP001AIN01";

Will look up the workspace id for the specified key vault and add it if it doesn't exist or doesn't match.

#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory = $true)]
	[string]$kv,
	[Parameter(Mandatory = $true)]
	[string]$resourceGroupName,
	[Parameter(Mandatory = $true)]
	[string]$appInsightsName
)

$ErrorActionPreference = "Stop";

Write-Output "Starting Get-WorkspaceIdToKeyvault -kv $kv -resouceGroupName $resourceGroupName -appInsightsName $appInsightsName";

$appiKey = (Get-AzApplicationInsights -ResourceGroupName $resourceGroupName -Name $appInsightsName).InstrumentationKey;
$secretName = "appinsights-instrumentationkey";
$secret = Get-AzKeyVaultSecret -VaultName $kv -Name $secretName;

if (($null -eq $secret) -or $secret.SecretValueText -ne $appiKey)
{
		Write-Output "Upserting Keyvault entry";
		$value = ConvertTo-SecureString $appiKey -AsPlainText  -Force;
		$res = Set-AzKeyVaultSecret -VaultName $kv -Name $secretName -SecretValue $value;
}
else
{
	Write-Output "Keyault Entry already exists";
}

Write-Output "Script Completes successfully"