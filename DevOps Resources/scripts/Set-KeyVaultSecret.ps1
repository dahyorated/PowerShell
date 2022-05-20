[CmdletBinding()]
param(
	[Parameter(Mandatory=$true,Position=1)]
	[string]$KeyVaultName,
	[Parameter(Mandatory=$true,Position=2)]
	[string]$SecretName,
	[Parameter(Mandatory=$true,Position=3)]
	[string]$SecretText
)
$secretValue = ConvertTo-SecureString $SecretText -AsPlainText -Force;
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $secretValue;
