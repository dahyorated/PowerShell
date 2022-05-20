<#
.SYNOPSIS
Creates a secret in a key vault

.DESCRIPTION
The New-KVSecret function creates the ($secretName) with the ($secretValueText) in ($keyVaultName).

.PARAMETER KeyVaultName
The key vault to add the secret.

.PARAMETER SecretName
The name of the secret to be added.

.PARAMETER SecretValueText
The value of the secret to be added.

.EXAMPLE
New-KVSecret -KeyVaultName EUWDGTP005AKV01 -SecretName configServiceSecret -SecretValueText "8f9c422c-be06-4f7e-8aeb-ef5f2fc76790";

#>
Function New-KVSecret
{
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true)]
		[string]$KeyVaultName,
		[Parameter(Mandatory=$true)]
		[string]$SecretName,
		[Parameter(Mandatory=$true)]
		[string]$SecretValueText
	)
	$secretValue = ConvertTo-SecureString $SecretValueText -AsPlainText -Force;
	try
	{
		Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $secretValue -ErrorAction Stop;
	}
	catch
	{
		$errorMessage = "Set-AzKeyVaultSecret: {0}" -f $_.Exception.Message;
		Stop-ProcessError -ErrorMessage $errorMessage;
	}
	try
	{
		$newSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop;
	}
	catch
	{
		$errorMessage = "Get-AzKeyVaultSecret: {0}" -f $_.Exception.Message;
		Stop-ProcessError -ErrorMessage $errorMessage;
	}
	$newSecretValue = $newSecret.SecretValueText;
	return $newSecret;
}
