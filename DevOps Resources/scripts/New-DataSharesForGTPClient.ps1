[CmdletBinding()]
param (
	[Parameter(Mandatory = $True)]
	[string]$sendLocation,
	[Parameter(Mandatory = $True)]
	[string]$clientId,
	[Parameter(Mandatory = $True)]
	[string]$sendResourceGroup,
	[Parameter(Mandatory = $True)]
	[string]$invitationEmail,
	[Parameter(Mandatory = $True)]
	[string] $sendAuthServiceURL,
	[Parameter(Mandatory = $True)]
	[string] $sendClientServiceURL,
	[Parameter(Mandatory = $True)]
	[string]$sendkeyVault,
	[Parameter(Mandatory = $True)]
	[string]$subscriptionId,
	[Parameter(Mandatory = $True)]
	[string]$DataShareFullPath,
	[Parameter(Mandatory = $True)]
	[string]$receiveResourceGroup,
	[Parameter(Mandatory = $True)]
	[string]$receiveLocation,
	[Parameter(Mandatory = $True)]
	[string] $receiveAuthServiceURL,
	[Parameter(Mandatory = $True)]
	[string] $receiveClientServiceURL,
	[Parameter(Mandatory = $True)]
	[string]$receivekeyVault,
	[Parameter(Mandatory = $True)]
	[string]$SPNName,
	[Parameter(Mandatory = $True)]
	[string]$SPNId,
	[Parameter(Mandatory = $True)]
	[string]$OmsWorkSpaceId,
	[Parameter(Mandatory = $True)]
	[string]$OmsWorkSpaceResourceGroup,
	[Parameter(Mandatory = $True)]
	[string]$OmsWorkSpaceName,
	[Parameter(Mandatory = $True)]
	[string]$tenantId
)

Function Save-Parameters {
	param(
		[System.IO.FileInfo]$parameterFile,
		$parametersJson
	)
	Write-Verbose $parametersJson;
	$parametersJson | ConvertTo-Json -Depth 100 | Out-File -FilePath $parameterFile -Force;
}

Function New-RoutingForDataShare {
	

	[CmdletBinding()]
	param(
		[int] $clientid,
		[string]  $account,
		[string] $kv,
		[string] $regionCd
	)
	

	$sql = "DECLARE @clientId BIGINT = $clientId
			DECLARE @account NVARCHAR(100) = '$account'
			DECLARE @regionCd nvarchar(100) = '$regionCd'

			INSERT INTO [Common].[ClientServiceConfiguration] ([ClientConfigId],[Service],[ResourceTypeId],[AccountName],[Container],[IsProvisioned],[IsRequired],[IsFailed]
					   ,[ErrorCd],[GTPRecordStatusId],[IsDeleted],[CreatedUser],[CreatedDtm],[UpdatedUser],[UpdatedDtm])
				 SELECT cc.ClientConfigId,csc.[Service],8,@account,csc.Container,1,1,0,0,1,0,'script',GETUTCDATE(),'script',GETUTCDATE()
			FROM Common.ClientConfiguration cc
			INNER JOIN Common.ClientServiceConfiguration csc ON cc.ClientConfigId = csc.ClientConfigId
			INNER JOIN common.AzureRegion ar ON cc.AzureRegionId = ar.AzureRegionId
			WHERE cc.ClientId = @clientId
			AND csc.ResourceTypeId = 1
			AND ar.AzureRegionCd = @regionCd"

	$connString = (Get-AzKeyVaultSecret -VaultName $kv -Name 'connectionstring-clientdb').SecretValueText;
	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    
	try {
		$sqlConnection.ConnectionString = $connString
		$sqlConnection.Open();

		$cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
		$res = $cmd.ExecuteNonQuery();
		$sqlConnection.Close();
	}
	Catch {
		Throw $_
	}

}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

#first check to make sure the DR Storage Account exists
try {
$receiveClientConfig = Get-ClientConfiguration -AuthService  $receiveAuthServiceURL  -ClientService $receiveClientServiceURL  -KeyVault  $receiveKeyvault -ClientId $clientId
}
catch { 

    Write-Output "Error: unable to get client configuration on DR Side for $clientID skipping it" 
    $message = "Error: {0}" -f $_.Exception.Message; 
    Write-output $message;
    return; 
};

if ($receiveClientConfig.storageAccounts.Count -eq 0)
{
	Write-Output "Error - no Storage Account for DR side - skipping";
	return;
}

$receiveStorageAccountName = $receiveClientConfig.storageAccounts[0].storageAccount; 

Write-Output "Starting DataShares for Client ID $clientId"

$intClientID = $clientId -as [int]; 

$spnSecretName= ("SPNKey-" + $SPNName) -replace "_", "-";

$SPNSecret = (Get-AzKeyVaultSecret -VaultName $sendkeyVault -Name $spnSecretName).SecretValueText;
$omsWorkspaceSecretName = "WorkspaceKey-" + $OmsWorkSpaceName;
$omsWorkspaceKey = (Get-AzKeyVaultSecret -VaultName $sendkeyVault -Name $omsWorkspaceSecretName).SecretValueText;

#create JSON for provisioning send
$createParam = @{
	parameters = @{
		location					= $sendLocation
		deployto					= "TENANT"
		clientId					= $clientId
		resourceGroup				= $sendResourceGroup
	    AZURE_RM_CLIENTID           = $SPNId
        AZURE_RM_TENANTID           = $tenantID
        AZURE_RM_SECRET             = $SPNSecret
        AZURE_RM_SUB                = $subscriptionId
        var_azureRmSubId            = $subscriptionId
        var_azure_rm_subid          = $subscriptionId
        var_omsSubscriptionId       = $subscriptionId
        var_omsResourceGroup        = $omsWorkSpaceResourceGroup
        var_omsWorkspaceName        = $omsWorkspaceName
        var_omsMyWorkSpaceId        = $omsWorkspaceId
        var_omsMyWorkspaceKey       = $omsWorkspaceKey
		var_tenantResourceGroupName = $sendResourceGroup
    
	}
}


$fileName = "ADS-$clientId.json"
if ($DataShareFullPath.StartsWith('.')) {
	$DataShareJson = Join-Path $PWD $DataShareFullPath;
}
else {
	$DataShareJson = $DataShareFullPath;
}

$res = New-Item -ItemType Directory -Force -Path $DataShareFullPath;


$DataShareJson = Join-Path $DataShareJson $fileName
$invFileName = "ADS-$clientId-Invite.txt";
$invitationFilePath = Join-Path $DataShareFullPath  $invFileName


write-output 'saving file '
Save-Parameters $DataShareJson $createParam;
#create the send datashare
. $PSScriptRoot\New-AzureDataShare -DataShareFullPathname $DataShareJson

$dataShareResult = Get-Content -Raw -Path $DataShareJson | ConvertFrom-Json

#the name of the created share
$sendDataShareAccountName = $dataShareResult.results.dataShareName

$containers = $receiveClientConfig.storageAccounts | Where-Object -Property regionCode -eq "eastus" | Select-Object -ExpandProperty container | Sort-Object -Unique

#get the configuration
$clientConfig = Get-ClientConfiguration -AuthService $sendAuthServiceURL   -ClientService $sendClientServiceURL  -KeyVault  $sendkeyVault -ClientId $clientId
$sendStorageAccountName = $clientConfig.storageAccounts[0].storageAccount; 

$inviteName = "Client" + $intClientID + "Invitatation"

try {
	. $PSScriptRoot\New-SendDataShare -ResourceGroupName $sendResourceGroup -DataShareAccountName $sendDataShareAccountName -ShareName "DRSendShare" -StorageAccountName $sendStorageAccountName  `
		-Containers $containers -TargetEmail $invitationEmail -InvitationName $inviteName -InvitationIdFilePath $invitationFilePath -shareSubscriptionId $subscriptionId;
}
catch { Write-Host "Error: " $_; throw; };

#create JSON for provisioning receive
$createParam = @{
	parameters = @{
		location					= $receiveLocation
		deployto					= "TENANT"
		clientId					= $clientId
		resourceGroup				= $receiveResourceGroup
		AZURE_RM_CLIENTID           = $SPNId
        AZURE_RM_TENANTID           = $tenantID
        AZURE_RM_SECRET             = $SPNSecret
        AZURE_RM_SUB                = $subscriptionId
        var_azureRmSubId            = $subscriptionId
        var_azure_rm_subid          = $subscriptionId
        var_omsSubscriptionId       = $subscriptionId
        var_omsResourceGroup        = $OmsWorkSpaceResourceGroup
        var_omsWorkspaceName        = $omsWorkspaceName
        var_omsMyWorkSpaceId        = $omsWorkspaceId
        var_omsMyWorkspaceKey       = $omsWorkspaceKey
		var_tenantResourceGroupName = $receiveResourceGroup
	}
}

$fileName = "ADS-$clientId-REC.json"
if ($DataShareFullPath.StartsWith('.')) {
	$DataShareJson = Join-Path $PWD $DataShareFullPath;
}
else {
	$DataShareJson = $DataShareFullPath;
}

$DataShareJson = Join-Path $DataShareJson $fileName

write-output "DataShareJson $DataShareJson createParam $createParam"
Save-Parameters $DataShareJson $createParam;
#create the send datashare
. $PSScriptRoot\New-AzureDataShare -DataShareFullPathname $DataShareJson

$dataShareResult = Get-Content -Raw -Path $DataShareJson | ConvertFrom-Json

#the name of the created share
$receiveDataShareAccountName = $dataShareResult.results.dataShareName

#get invitation ID from file
$invitationId = Get-Content -Raw -Path $invitationFilePath

. $PSScriptRoot\New-ReceiveDataShare -ResourceGroupName $receiveResourceGroup -DataShareAccountName $receiveDataShareAccountName -ReceivedName "DRReceiveShare" -StorageAccountName $receiveStorageAccountName -InvitationId $invitationId -StartSynchronization $false -SynchronizationTime "1/31/2020 17:00" -RecurrenceInterval Hour 

New-RoutingForDataShare -clientid $clientId -account $sendDataShareAccountName -kv $sendkeyVault -regionCd 'westeurope'; 
New-RoutingForDataShare -clientid $clientId -account $receiveDataShareAccountName -kv $sendKeyVault  -regionCd 'eastus'; 

Write-Output "Finished DataShares for Client ID $clientId"
