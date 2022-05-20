<#
.Synopsis
Get a secret or set of secrets from a key vault.

.Description
The Get-KeyVaultSecret script gets a secret for -SecretName or set of secrets that match -Like from key vault -KeyVaultName.

When using -Like, the entire contents of the key vault is cached in a global variable named $kvs.

.Parameter SecretName
This is the exact name of a secret.

.Parameter Like
This is a pattern (with wild cards) for the secrets to be retrieved.

.Parameter KeyVaultName
This is the name of the key vault containing the requested secret(s).

.Parameter Refresh
If specified, the contents of $global:kvs cache is refreshed. Otherwise, its contents are used if the global exists.

.Outputs
The script writes one line of output for each secret. The results look like the following where <<secret1>> and <<secret2>> are the secret values.

Name: EUWDGTP005SQL01-sqlTenantAdminPass, Secret: <<secret1>>
Name: EUWDGTP006SQL01-sqlTenantAdminPass, Secret: <<secret2>>

.Example

Get-KeyVautlSecret -Like '*-Admin*' -KeyVaultName EUWDGTP005AKV01;

This get all secrets matching '*-Admin*' from the EUWDGTP005AKV01 key vault.

.Example
Get-KeyVautlSecret -SecretName 'Xyzzy' -KeyVaultName EUWDGTP005AKV01;

This gets the secret named 'Xyzzy' from the EUWDGTP005AKV01 key vault.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$SecretName = '',
	[Parameter(Mandatory=$False)]
	[string]$Like = "*",
	[Parameter(Mandatory=$False)]
	[string]$KeyVaultName = "EUWDGTP005AKV01",
	[switch]$Refresh
)
if (-not [string]::IsNullOrWhiteSpace($SecretName))
{
	Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName;
}
else
{
	if (-not $global:kvs -or $Refresh)
	{
		$global:kvs = Get-AzKeyVaultSecret -VaultName $KeyVaultName;
	}
	$kvs | Where-Object Name -like $Like | ForEach-Object {
		$secret = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $_.Name).SecretValueText;
		Write-Output "Name: $($_.Name), Secret: $($secret)";
	};
}
