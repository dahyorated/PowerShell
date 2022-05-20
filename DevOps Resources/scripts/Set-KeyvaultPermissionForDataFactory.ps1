<#
.Synopsis
Grants a Data Factory access to read secrets from a keyvault

.Description
Grants a Data Factory access to read secrets from a keyvault

.Parameter subscriptionId
This is the ID of the subscription containing the function and data factory;

.Parameter ResourceGroupName
This is the resource group containing -FunctionName.

.Parameter KeyVault
This is the Keyvault getting the permission update

.Parameter DataFactoryName
This is the name of the Data Factory to give access to keyvault secrets

.Example
Set-KeyvaultPermissionForDataFactory.ps1 -SubscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -DataFactoryName "EUWDGTP005DFA02" -KeyVault "EUWDGTP005AKV01" -Verbose;

#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
param(
	[Parameter(Mandatory = $true)]
	[string] $SubscriptionId,
	[Parameter(Mandatory = $true)]
	[string] $ResourceGroupName,
	[Parameter(Mandatory = $true)]
	[string] $KeyVault,
	[Parameter(Mandatory = $true)]
	[string] $DataFactoryName
)

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

Write-Output "Starting Set-KeyvaultPermissionForDataFactory.ps1"

if ($isVerbose) {
		Write-NameAndValue "subscriptionId" $subscriptionId;
		Write-NameAndValue "ResourceGroupName" $ResourceGroupName;
		Write-NameAndValue "KeyVault" $KeyVault;
		Write-NameAndValue "DataFactoryName" $DataFactoryName;
}

$dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Name $DataFactoryName;
$objectId = $dataFactory.Identity.PrincipalId;


Write-Verbose "ObjectId: $objectId ";



try {
	Set-AzKeyVaultAccessPolicy -VaultName $KeyVault -ResourceGroupName $ResourceGroupName -ObjectId $objectId -PermissionsToSecrets list,get
	
	}
catch
{
		$message = "Error: {0}" -f $_.Exception.Message;
		Stop-ProcessError -errorMessage $message;
	}

Write-Output "Finished Set-KeyvaultPermissionForDataFactory.ps1";
