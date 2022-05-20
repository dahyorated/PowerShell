<#
.SYNOPSIS
Create an Azure Data Share Send Sent Share with dataset(s) and an invitation.

.DESCRIPTION
1) Get the invitation to look up invitation id
2) Lookup Storage Account Resource Id
3) Create a Dataset within the share for each container in the invitation - will map to a container with the same name (does not need to previously exist)
4) Create the Synchronization Setting - the Interval and Time MUST exactly match from the invitation
5) Create the invitation
6) Create the trigger
7) Optionally start synchronizing - if -StartSynchronization is not specified, will wait based on the -RecurrenceInterval

.PARAMETER ResourceGroupName
Resource Group Name for the Azure Data Share

.PARAMETER DataShareAccountName
Azure Data Share Account Name

.PARAMETER ShareName
Name of the Sent Share

.PARAMETER StorageAccountName
Storage Account Name

.PARAMETER RecurrenceInterval
Optional - Interval can be Hour or Day - defaults to Day

.PARAMETER SynchronizationTime
Optional - Date Time (UTC) to start synchronizing - only really needed if desired at a specific time or future start.

.PARAMETER StartSynchronization
if specified, begin the synchronization after creation. This is done synchronously so it may cause the script to take a long time to run.

.Example 
New-ReceiveDataShare.ps1 -ResourceGroupName "GTP-ADS-Spike" -DataShareAccountName "euwads02" -ReceivedName "FromScript2" -StorageAccountName "euwadssta02" -InvitationId "/subscriptions/3efbb09c-de65-4ed0-b6e3-4fc77081ccb3/resourceGroups/GTP-ADS-Spike/providers/Microsoft.DataShare/accounts/euwads01/shares/FromScript/invitations/ScriptedInvitation" -StartSynchronization;

Typical use create a receive share in specified resource group and share account named Fromscript2 from an invitation and start the synchronization.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $True)]
    [string]$DataShareAccountName, 
    [Parameter(Mandatory = $True)]
    [string]$ReceivedName,
    [Parameter(Mandatory = $True)]
    [string]$StorageAccountName,
    [Parameter(Mandatory = $True)]
    [string]$InvitationId,
    [Parameter(Mandatory = $false)]
    [bool]$StartSynchronization=$true,
    [Parameter(Mandatory = $false)]
    [string]$SynchronizationTime = "1/31/2020 17:00",
    [Parameter(Mandatory = $false)]
    [ValidateSet("Hour", "Day")]
    [string]$RecurrenceInterval = "Hour"    
)

$ErrorActionPreference = "Stop"

Write-Output "Starting New-ReceiveDataShare";

#the cmdlet below is ignoring the invitation id from create and gettign all outstanding - this will need to change in order to allow parallel processing 
$invitation = Get-AzDataShareReceivedInvitation -InvitationId $InvitationID;
Write-Output "Creating Received Share: $ReceivedName";

$shareSubscription = New-AzDataShareSubscription -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -Name $ReceivedName -InvitationId $invitation.InvitationId;

$DataShareAccount = Get-AzDataShareAccount -ResourceGroupName $ResourceGroupName -Name $DataShareAccountName;

$StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName;

. $PSScriptRoot\Assign-PermissionForDatashare -DataShareAccountResourceId $DataShareAccount.Id  -StorageAccountResourceId $storageAccount.Id -Role 'write';

#sleep 30 seconds to ensure permission has been assigned
Start-Sleep -s 30

$datasets = Get-AzDataShareSourceDataSet -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -ShareSubscriptionName $ReceivedName;
foreach ($dataset in $datasets) {
    Write-Output "Creating mapping for container: " $dataset.DataSetName;
    $mapping = New-AzDataShareDataSetMapping -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -ShareSubscriptionName $ReceivedName -Name $dataset.DataSetName -StorageAccountResourceId $StorageAccount.Id -DataSetId $dataset.DataSetId -Container $dataset.DataSetName;
}

#following line should enable the 
Write-Output "Creating Trigger;"
New-AzDataShareTrigger -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -ShareSubscriptionName $ReceivedName -Name Trigger -RecurrenceInterval $RecurrenceInterval -SynchronizationTime $SynchronizationTime;

if ($StartSynchronization) {
    Write-Output "Starting Synchronization THIS MAY A TAKE A LONG TIME TO COMPLETE!";
    Start-AzDataShareSubscriptionSynchronization -ResourceGroupName $ResourceGroupName -AccountName $DataShareAccountName -ShareSubscriptionName $ReceivedName -SynchronizationMode "Incremental";
}

Write-Output "New-ReceiveDataShare has completed";
