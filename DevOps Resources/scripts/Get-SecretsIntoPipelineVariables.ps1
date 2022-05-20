<#
.SYNOPSIS
This script obtains the secret for the targeted secret name from the key vault.

.DESCRIPTION
This script obtains the secrets for the targeted secret names (-SecretNames) from the key vault (-KeyVaultName).
The results are placed in the pipeline variables (-VariableNames).

.PARAMETER KeyVaultName
This is the key vault to search.

.PARAMETER SecretNames
This is the set of the names of secrets.

.PARAMETER VariableNames
This is the set of pipeline variable names to be created.

.EXAMPLE
Get-SecretsIntoPipelineVariables -KeyVault EUWDGTP005AKV01 -SecretNames @('mdedbuser') -VariableName @('TargetPassword')

This get the secret value of 'mdedbuser' from the EUWDGTP005AKV01 key vault and put the result into the 'TargetPassword' pipeline variable.

.EXAMPLE
Get-SecretsIntoPipelineVariables -KeyVault EUWDGTP005AKV01 -SecretNames @('mdedbuser','clientdbuser') -VariableName @('MdePassword','ClientPassword');

This get the secret values of 'mdedbuser' and clientdbuser from the EUWDGTP005AKV01 key vault and
respectively puts the results into the 'MdePassword' and 'ClientPassword' pipeline variables.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True)]
	[string]$KeyVaultName,
	[Parameter(Mandatory=$True)]
	[string[]]$SecretNames,
	[Parameter(Mandatory=$False)]
	[string[]]$VariableNames = @("TargetPassword")
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$count = $SecretNames.Count;
if ($VariableNames.Count -ne $count)
{
	$errorMessage = "Size of -SecretName ({0}) must be the same as the size of -VariableNames ({1})." -f $count,$VariableNames.Count;
	Stop-ProcessError -errorMessage $errorMessage;
}
for ($i=0; $i -lt $count; $i++)
{
	$secretValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretNames[$i]).SecretValueText;
	Write-Output "##vso[task.setvariable variable=$($VariableNames[$i])]$secretValue";
}
