<#
.SYNOPSIS
Get a secret from all key vaults.

.DESCRIPTION
This gets the -SecretName secret from all key vaults.

.PARAMETER SecretName
This is the name of the key vault secret. The wildcard character ('*') is not supported.

.EXAMPLE
Get-KeyVaultSecretsAllEnvironments -SecretName transformationdbuser

This gets the "transformationdbuser" secret from all key vaults.
#>
[CmdletBinding()]
param(
	[string]$SecretName
)
if ($SecretName.Contains('*'))
{
	Write-Output "Wildcard character ('*') is not supported.";
	Exit
};
$Stages = 'DEV','QAT','UAT','PRF','DMO','STG','PRD','DEV-DR','STG-DR','PRD-DR';
$KvNames = 'EUWDGTP005AKV01','EUWQGTP007AKV01','EUWUGTP014AKV01','EUWFGTP012AKV01','EUWEGTP035AKV09','EUWXGTP020AKV01','EUWPGTP018AKV04','USEDGTP004AKV01','USEXGTP021AKV01','USEPGTP019AKV04';
for ($i =0; $i -lt $Stages.Count; $i++)
{
	$secret = (Get-AzKeyVaultSecret -VaultName $KvNames[$i] -Name $SecretName).SecretValueText;
	Write-Output "Stage: $($Stages[$i]), Name: $($KvNames[$i]), Secret: '$($secret)'";
};
