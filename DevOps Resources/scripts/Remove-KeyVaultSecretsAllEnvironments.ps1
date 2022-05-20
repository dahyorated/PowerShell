<#
.SYNOPSIS
Remove a secret from all key vaults.

.DESCRIPTION
This removes the -SecretName secret from all key vaults.

.PARAMETER SecretName
This is the name of the key vault secret.

.EXAMPLE
Remove-KeyVaultSecretsAllEnvironments -SecretName transformationdbuser

This removes the "transformationdbuser" secret from all key vaults.
#>
[CmdletBinding()]
param(
	[string]$SecretName
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$Stages = 'DEV','QAT','UAT','PRF','DMO','STG','PRD','DEV-DR','STG-DR','PRD-DR';
$KvNames = 'EUWDGTP005AKV01','EUWQGTP007AKV01','EUWUGTP014AKV01','EUWFGTP012AKV01','EUWEGTP035AKV09','EUWXGTP020AKV01','EUWPGTP018AKV04','USEDGTP004AKV01','USEXGTP021AKV01','USEPGTP019AKV04';
for ($i =0; $i -lt $Stages.Count; $i++)
{
	$secret = (Get-AzKeyVaultSecret -VaultName $KvNames[$i] -Name $SecretName).SecretValueText;
	if ([string]::IsNullOrWhiteSpace($secret))
	{
		Write-Host "Stage: $($Stages[$i]), Name: $($KvNames[$i]), Secret: 'None', Skipping";
		continue;
	}
	Write-Host "Stage: $($Stages[$i]), Name: $($KvNames[$i]), Secret: '$($secret)', Removing";
	Remove-AzKeyVaultSecret -VaultName $KvNames[$i] -Name $SecretName;
};
