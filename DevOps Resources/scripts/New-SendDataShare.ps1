<#
.SYNOPSIS
Create an Azure Data Share Send Sent Share with dataset(s) and an invitation.

.DESCRIPTION
1) Create the Share
2) Lookup Storage Account Resource Id
3) Create a Dataset within the share for each container in the input array
4) Create the Synchronization Setting
5) Create the invitation
6) Output the Invitation ID - optionally to a file and to a Azure DevOps Pipeline variable

.OUTPUTS
The Invitation ID is necessary to process the subscription. Optionally will be written to a file and to an Azure DevOps Pipeline variable "InvitationId"

.PARAMETER ResourceGroupName
Resource Group Name for the Azure Data Share

.PARAMETER DataShareAccountName
Azure Data Share Account Name

.PARAMETER ShareName
Name of the Sent Share

.PARAMETER StorageAccountName
Storage Account Name

.PARAMETER Containers
Array of Container Names

.PARAMETER TargetEmail
Email Address for the Invitation

.PARAMETER InvitationName
Name for Invitation

.PARAMETER InvitationIdFilePath
Optional - file path to write the invitation id - used in case it needs to be picked up for later use 

.PARAMETER RecurrenceInterval
Optional - Interval can be Hour or Day - defaults to Day

.PARAMETER SynchronizationTime
Optional - Date Time (UTC) to start synchronizing - only really needed if desired at a specific time or future start
    defaults to 1/31/2020 17:00Z

.Example 
New-SendDataShare.ps1 -ResourceGroupName "GTP-ADS-Spike" -DataShareAccountName "euwads01" -ShareName "FromScript" -StorageAccountName "euwadssta01" -Containers @("testcontainer","testcontainer2") -TargetEmail "A1232105-MSP01@EY.NET" -InvitationName "ScriptedInvitation";

Typical use - Create a Share name "FromScript" for the specified Resource Group and Account name and storage account with two containers.

.Example 
New-SendDataShare.ps1 -ResourceGroupName "GTP-ADS-Spike" -DataShareAccountName "euwads01" -ShareName "FromScript" -StorageAccountName "euwadssta01" -Containers @("testcontainer","testcontainer2") -TargetEmail "A1232105-MSP01@EY.NET" -InvitationName "ScriptedInvitation" -RecurrenceInterval "Day" -SynchronizationTime "1/15/2030 0:00Z";

Future Date Daily Sync - Create a Share name "FromScript" for the specified Resource Group and Account name and storage account with two containers.

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$True)]
    [string]$DataShareAccountName, 
    [Parameter(Mandatory=$True)]
    [string]$ShareName,
    [Parameter(Mandatory=$True)]
    [string]$StorageAccountName,
    [Parameter(Mandatory=$True)]
    [string[]]$Containers,
    [Parameter(Mandatory=$True)]
    [string]$TargetEmail,
    [Parameter(Mandatory=$True)]
    [string]$InvitationName,
    [Parameter(Mandatory=$false)]
    [string]$InvitationIdFilePath = "N/A",
    [Parameter(Mandatory=$false)]
    [ValidateSet("Hour","Day")]
    [string]$RecurrenceInterval = "Hour",
    [Parameter(Mandatory=$false)]
    [string]$SynchronizationTime="1/31/2020 17:00Z",
    [Parameter(Mandatory=$true)]
    [string]$shareSubscriptionId,
    [Parameter(Mandatory=$false)]
    [string]$storageSubscriptionId=""
    
)

$ErrorActionPreference = "Stop"

Write-Output "Starting New-SendDataShare ResourceGroupName: $ResourceGroupName DataShareAccountName: $DataShareAccountName SubscriptionId $shareSubscriptionId" ;

Set-AzContext -SubscriptionId $shareSubscriptionId;
$DataShareAccount = Get-AzDataShareAccount -ResourceGroupName $ResourceGroupName -Name $DataShareAccountName;

Write-Output "creating Sent Share $ShareName";
$share = New-AzDataShare -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -Name $ShareName;

if ($storageSubscriptionId -eq "") {
    $storageSubscriptionId  = $shareSubscriptionId;
}

#if we need to work with multiple subscriptions, set to subscription
if ($storageSubscriptionId -ne $shareSubscriptionId) {
    Set-AzContext -SubscriptionId $storageSubscriptionId;
}
$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName;


. $PSScriptRoot\Assign-PermissionForDatashare -DataShareAccountResourceId $DataShareAccount.Id  -StorageAccountResourceId $storageAccount.Id -Role 'read';

#sleep 30 seconds to ensure assignment exists
Start-Sleep -s 30

$storageAccountResourceId = $storageAccount.Id
$ctx = $storageAccount.Context;
$existingContainers = Get-AzStorageContainer -Context $ctx | Select-Object -ExpandProperty Name;

#first ensure containers exist
foreach ($containerName in $Containers) {
    if ($existingContainers -eq $null -or !$existingContainers.Contains($containerName)) {
        Write-Host "Creating missing Container: $containerName";
        New-AzStorageContainer -Name $containerName -Context $ctx;
    }
}

##if multiple subscriptions, reset to share
if ($shareSubscriptionId -ne $storageSubscriptionId) {
    Set-AzContext -SubscriptionId $shareSubscriptionId;
}

#create the datasets
foreach ($containerName in $Containers) {
    Write-Output "Creating dataset for container: $containerName";
    try {
    $dataset =  New-AzDataShareDataSet -ResourceGroupName $ResourceGroupName  -AccountName $DataShareAccountName -ShareName $ShareName -Name $containerName -StorageAccountResourceId $storageAccountResourceId -Container $containerName;
    }
    catch { Write-Host $_ };

}

Write-Output "creating Synchronization Setting";
$syncSetting = New-AzDataShareSynchronizationSetting -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -ShareName $ShareName -Name "sync" -RecurrenceInterval $RecurrenceInterval -SynchronizationTime "1/31/2020 17:00";

Write-Output "creating Invitation";
$invitation = New-AzDataShareInvitation -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -ShareName $ShareName -TargetEmail $TargetEmail -Name $InvitationName;

$invitationId = $invitation.Id;
Write-Host "##vso[task.setvariable variable=InvitationId]$invitationId";

Write-Output "Invitation created - Invitation ID:" $invitationId;

if ($InvitationIdFilePath -ne "N/A") {
    #validate path's directory
    # TODO DS Following statement can throw an exception. Should try catch and write pipeline error.
    [System.IO.FileInfo]$path = $InvitationIdFilePath;
    if (!($path.Directory.Exists))
    {
        Write-Error "Invalid folder in InvitationIdFilePath $path.Directory " 
    }
    Set-Content -Path $InvitationIdFilePath -Value $invitationId;
}

Write-Output "Completed New-SendDataShare";
