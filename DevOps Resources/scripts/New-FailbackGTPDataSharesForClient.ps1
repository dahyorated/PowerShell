<#
.SYNOPSIS
Completes Processing to fail data storage account blobs from DR (US East) back to Primary (West Europe) for GTP

.DESCRIPTION

1)disable receive share on USE
2) Create invitation a Send on Use from West Europe - no sync one time only
3) use invitation to accept a receive on west europe from use (no sync one time only)
4) synchronize on time - (wait this can take a long time) if fails - retry


NOTE!!!

the parameters names using "send" and "receive" are named to be consistent with the GTP DR Strategy meaning we "Send" (primary) West Europe, and "Receive" (DR) East US
This is actually the "reverse" of the flow of data in this script (since it's purpose is to "revert") but naming it this way allows parameters to be consistent with other 
DR scripts!

.PARAMETER subscriptionId
Subscription Id

.PARAMETER receiveResourceGroupName
Resource Group Name for DR Site

.PARAMETER receiveDataShareAccountName
Azure Data Share Account Name for the DR Site

.PARAMETER origReceiveShareName
Name of the share for reverting from DR Site to be disabled

.PARAMETER newReceiveShareName
Name of the new share for copying from DR Site back to Primary

.PARAMETER receiveStorageAccountName
Storage Account Name for DR Storage

.PARAMETER TargetEmail
Email to use for Invitation

.PARAMETER intClientID
Client ID  - should be an int (ie not left zero filled)

.PARAMETER sendResourceGroupName
Resource Group for Primary

.PARAMETER sendDataShareAccountName
Data Share Account Name for Primary

.PARAMETER sendShareName
Share name for Primary

.PARAMETER sendstorageAccountName
Storage Account Name for Primary

.Example 
.\New-FailbackGTPDataSharesForClient.ps1 -subscriptionId "2933b9c9-b1f2-4fd6-a201-b8e5e496bb86" -receiveResourceGroupName  "GT-EUS-GTP-TENANT-DEV-RSG" -receiveDataShareAccountName  "UE2DGTP242ADS03" -receiveShareName "DRReceiveShare" `
		-receiveStorageAccountName "usedgtp242sta05" -TargetEmail  "A1232105-MSP01@EY.NET" -intClientID  242 -sendResourceGroupName "GT-WEU-GTP-TENANT-DEV-RSG" -sendDataShareAccountName  "EUWDGTP242ADS01" -sendShareName  "DRFailbackReceive"-sendstorageAccountName "euwdgtp242sta05"

#>

   
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    [string]$subscriptionId,
    [Parameter(Mandatory = $True)]
    [string]$receiveResourceGroupName,
    [Parameter(Mandatory = $True)]
    [string]$receiveDataShareAccountName,
    [Parameter(Mandatory = $True)]
    [string]$origReceiveShareName,
    [Parameter(Mandatory = $True)]
    [string]$newReceiveShareName,
    [Parameter(Mandatory = $True)]
    [string]$receiveStorageAccountName,
    [Parameter(Mandatory = $True)]
    [string]$TargetEmail,
    [Parameter(Mandatory = $True)]
    [string]$intClientID,
    [Parameter(Mandatory = $True)]
    [string]$sendResourceGroupName,
    [Parameter(Mandatory = $True)]
    [string]$sendDataShareAccountName,
    [Parameter(Mandatory = $True)]
    [string]$sendShareName,
    [Parameter(Mandatory = $True)]
    [string]$sendstorageAccountName
)


$ErrorActionPreference = "Stop"
Write-Output "Start New-FailbackGTPDataSharesForClient.ps1"

#first we disable the the synchronization from EUW to USE
Set-AzContext -SubscriptionId $subscriptionId;

Write-Output "Disabling Receive Share -ResourceGroupName $receiveResourceGroupName -AccountName $receiveDataShareAccountName -ShareSubscriptionName $receiveShareName "
try {
    $trigger = Get-AzDataShareTrigger -ResourceGroupName $receiveResourceGroupName -AccountName $receiveDataShareAccountName -ShareSubscriptionName $origReceiveShareName;
}
catch {
    Write-Host 'unable to find Datashare Trigger ' $_;
}

if ($trigger -ne $null) {
    Remove-AzDataShareTrigger -ResourceGroupName $receiveResourceGroupName -AccountName $receiveDataShareAccountName -ShareSubscriptionName $origReceiveShareName -Name $trigger.Name;
}
#Create invitation a Send on Use from West Europe - no sync one time only

$DataShareAccount = Get-AzDataShareAccount -ResourceGroupName $receiveResourceGroupName -Name $receiveDataShareAccountName;

Write-Output "creating Sent Share $newReceiveShareName";
$share = New-AzDataShare -ResourceGroupName $receiveResourceGroupName  -AccountName $receiveDataShareAccountName -Name $newReceiveShareName;


$storageAccount = Get-AzStorageAccount -ResourceGroupName $receiveResourceGroupName -Name $receiveStorageAccountName;

.\Assign-PermissionForDatashare.ps1 -DataShareAccountResourceId $DataShareAccount.Id  -StorageAccountResourceId $storageAccount.Id -Role 'read';
$storageAccountResourceId = $storageAccount.Id
$ctx = $storageAccount.Context;

$existingContainers = Get-AzStorageContainer -Context $ctx | Select-Object -ExpandProperty Name;

foreach ($containerName in $existingContainers) {
    #check if already exists from another DR (test or otherwise)
    
    try {
    $existingDataset = Get-AzDataShareDataSet -ResourceGroupName $receiveResourceGroupName  -AccountName $receiveDataShareAccountName -ShareName $newReceiveShareName -Name $containerName;
        }
    catch
    {
        #swallow exception - as it will cause an error if the Get fails because it doesn't exist
    }

    if ($existingDataset -eq $null) {

        Write-Output "Creating dataset for container: $containerName";
        try {
            $dataset = New-AzDataShareDataSet -ResourceGroupName $receiveResourceGroupName  -AccountName $receiveDataShareAccountName -ShareName $newReceiveShareName -Name $containerName -StorageAccountResourceId $storageAccountResourceId -Container $containerName;
        }
        catch { Write-Host $_ };
    }
}


#create the invitation
$invitationName = "Client" + $intClientID + "FailbackInvitatation"
write-output "Creating Invitation:  $InvitationName"
$invitation = New-AzDataShareInvitation -ResourceGroupName $receiveResourceGroupName -AccountName $receiveDataShareAccountName -ShareName $newReceiveShareName -TargetEmail $TargetEmail -Name $InvitationName;

#check if subscription already exists
try {
$existingShareSubscription = Get-AzDataShareSubscription -ResourceGroupName $sendResourceGroupName -AccountName $sendDataShareAccountName -Name $sendShareName
}
catch {
    #swallow exception 
}
if ($existingShareSubscription -eq $null) {
    Write-Output "Creating Receive share $sendShareName "
    $shareSubscription = New-AzDataShareSubscription -ResourceGroupName $sendResourceGroupName -AccountName $sendDataShareAccountName -Name $sendShareName -InvitationId $invitation.InvitationId;
}

$DataShareAccount = Get-AzDataShareAccount -ResourceGroupName $sendResourceGroupName -Name $sendDataShareAccountName;
$StorageAccount = Get-AzStorageAccount -ResourceGroupName $sendResourceGroupName -Name $sendstorageAccountName;
.\Assign-PermissionForDatashare.ps1 -DataShareAccountResourceId $DataShareAccount.Id  -StorageAccountResourceId $storageAccount.Id -Role 'write';

$datasets = Get-AzDataShareSourceDataSet -ResourceGroupName $sendResourceGroupName -AccountName $sendDataShareAccountName -ShareSubscriptionName $sendShareName;
foreach ($dataset in $datasets) {
    try {
    $existingMapping = Get-AzDataShareDataSetMapping -ResourceGroupName $sendResourceGroupName -AccountName $sendDataShareAccountName -ShareSubscriptionName $sendShareName -Name $dataset.DataSetName;
        }
    catch {
        # swallow exception - 
    }
    if ($existingMapping -eq $null) {
        Write-Output "Creating mapping for container: " $dataset.DataSetName;
        $mapping = New-AzDataShareDataSetMapping -ResourceGroupName $sendResourceGroupName -AccountName $sendDataShareAccountName -ShareSubscriptionName $sendShareName -Name $dataset.DataSetName -StorageAccountResourceId $StorageAccount.Id -DataSetId $dataset.DataSetId -Container $dataset.DataSetName;
    }
}

Write-Output "Starting Synchronization THIS MAY A TAKE A LONG TIME TO COMPLETE!";
Start-AzDataShareSubscriptionSynchronization -ResourceGroupName $sendResourceGroupName -AccountName $sendDataShareAccountName -ShareSubscriptionName $sendShareName -SynchronizationMode "FullSync" ;

Write-Output "Finish New-FailbackGTPDataSharesForClient.ps1"
