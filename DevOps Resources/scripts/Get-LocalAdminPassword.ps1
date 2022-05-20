[CmdletBinding()]
param(
	[Parameter(Mandatory=$False,ValueFromPipeline=$True)]
	[string]$MachineName = "EUWUGTPTAUMVM03"
)
$vm = Get-AzVM -Name $MachineName;
$resourceGroupName = $vm.ResourceGroupName;
$vaultNames = Get-AzKeyVault -ResourceGroupName $resourceGroupName;
$vaultName = $vaultNames[0].VaultName;
Write-Verbose "Vault: $vaultName";
$keyName = "{0}-LocalAdminPassword" -f $MachineName;
$password = (Get-AzKeyVaultSecret -VaultName $vaultName -Name "$keyName" -ErrorAction SilentlyContinue).SecretValueText;
Write-Host "$($MachineName): $password";
