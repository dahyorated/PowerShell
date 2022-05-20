<#
.SYNOPSIS
This script obtains Event grid topic key to be added to a KV entry to be used by a service

.PARAMETER KeyVaultName
This is the key vault to search.

.PARAMETER ResourceGroupName
This is the name of the resource group the event grid topic and key vault reside

.PARAMETER EventGridTopicName
This is the name of the event grid topic

.PARAMETER SecretName
The name of the key vault secret to store the event grid topic key within the key vault .

.EXAMPLE
New-EventGridTopicSassKey -KeyVaultName EUWDGTP005AKV01 -ResourceGroupName GT-WEU-GTP-CORE-DEV-RSG -EventGridTopicName EUWDGTP005ETN01 -SecretName ingestion-IngestProcessorConfig--EventGridKey

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$EventGridTopicName,
    [Parameter(Mandatory=$true)]
    [string]$SecretName
)

Write-Host "Getting $SecretName from key vault $KeyVaultName...";
$keyVaultValue  = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName;

Write-Host "Getting Key value from the Event Grid...";
$eventGridKeys = Get-AzEventGridTopicKey -ResourceGroupName $ResourceGroupName -Name $EventGridTopicName;

if($null -eq $keyVaultValue -or $eventGridKeys.Key1 -ne $keyVaultValue.SecretValueText){

    Write-Host -ForegroundColor Yellow "$SecretName doesn't exist or the Key has been rotated...";
    
    Write-Host "Creating new secret in $KeyVaultName";
    & "$PSScriptRoot\New-KVSecret.ps1" -KeyVaultName $KeyVaultName -SecretName "$SecretName" -SecretValueText $eventGridKeys.Key1;

    Write-Host -ForegroundColor Green "Event grid key has been added to $KeyVaultName as $SecretName";
} else {

    Write-Host -ForegroundColor Green "$SecretName exits in $KeyVaultName and the Key matches current Event Grid topic Key...";
}

