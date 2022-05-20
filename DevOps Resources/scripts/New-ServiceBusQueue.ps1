# New-ServiceBusQueue.ps1
<#
.SYNOPSIS
This script is idempotently provisions Service Bus Queue for GTP

.DESCRIPTION
This script will verify the namespace exists, then creates the servicebus queue. It will create an List,Send SAS Policy, and store the key in keyvault
The Secret name will be servicebus-sasRule-{queueName}

.PARAMETER kv
Azure Keyvault

.PARAMETER nameSpace
Azure Service Bus Namespace Name

.PARAMETER resourceGroup
The Azure Resource Group

.PARAMETER queueName
The desired Queue Name to create - if comma delimited - treat as array

.Example 
.\New-ServiceBusQueue.ps1 -kv "EUWDGTP005AKV01" -nameSpace "EUWDGTP005SBS01" -resourceGroup "GT-WEU-GTP-CORE-DEV-RSG" -queueName "DanTest1,DanTest2" 


#>

Param(
	[Parameter(Mandatory=$true)]
	[string]$kv,
	[Parameter(Mandatory=$true)]
	[string]$nameSpace,
	[Parameter(Mandatory=$true)]
	[string]$resourceGroup,
	[Parameter(Mandatory=$true)]
	[string]$queueName
)


Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;

Write-Output "New-ServiceBusQueue -kv $kv -nameSpace $nameSpace -resourceGroup $resourceGroup -queueName $queueName"

$ErrorActionPreference = "Stop"

#get namespace - this will cause script to fail if it doesn't exist
$currentNamespace = Get-AzServiceBusNamespace -ResourceGroupName $resourceGroup -NamespaceName $nameSpace

[array] $queArray = $queueName.Split(',');
foreach ($queueNameItem in $queArray) {
	Write-Output "creating queue $queueNameItem if it does not exist";
	$queue = New-AzServiceBusQueue -Namespace $nameSpace -ResourceGroupName $resourceGroup -Name $queueNameItem -DeadLetteringOnMessageExpiration $true

	$ruleName = $queueNameItem + "-AccessRule"
	$authRule = New-AzServiceBusAuthorizationRule -ResourceGroupName $resourceGroup -Namespace $nameSpace -Queue $queueNameItem -Name $ruleName -Rights @("Listen","Send");
	$authKey = Get-AzServiceBusKey -ResourceGroupName $resourceGroup -Namespace $nameSpace -Queue $queueNameItem -Name $ruleName;

	$secretName = "servicebus-sasRule-" + $queueNameItem
	$existingSecret = Get-AzKeyVaultSecret -VaultName $kv -Name $secretName

	$createSecret = $true
	if ($null -ne $existingSecret) {
		$existingValue = $existingSecret.SecretValueText
		if ($authKey.PrimaryKey -eq $existingValue) {
			Write-Output "secret already exists: $secretName"
			$createSecret = $false
		}
		else {
			Write-Output "updating secret $secretName"
		}
	}
	else {
		Write-Output "creating secret $secretName"
	}

	if ($createSecret) {
		$secretvalue = ConvertTo-SecureString $authKey.PrimaryKey -AsPlainText -Force
		$secret = Set-AzKeyVaultSecret -VaultName $kv -Name $secretName -SecretValue $secretvalue
	}
}
