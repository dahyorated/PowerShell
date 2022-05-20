[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[ValidateSet('','westeurope','eastus')]
	[string]$Location = '',
	[Parameter(Mandatory=$False)]
	[string]$ResourceGroupName = ''
)
if (-not [string]::IsNullOrWhitespace($Location))
{
	$vms = Get-AzVM -Location $Location;
}
elseif (-not [string]::IsNullOrWhitespace($ResourceGroupName))
{
	$vms = Get-AzVM -ResourceGroupName $ResourceGroupName;
}
else
{
	$vms = Get-AzVM;
}

return $vms | Where-Object {$_.OSProfile.LinuxConfiguration -ne $null};
