<#
.SYNOPSIS
Run Failback for All Clients.  See "New-FailbackGTPDataSharesForClient" for details on the process - this script reads client routing to find the clients to process failbacks for

.DESCRIPTION

1)disable receive share on USE
2) Create invitation a Send on Use from West Europe - no sync one time only
3) use invitation to accept a receive on west europe from use (no sync one time only)
4) synchronize on time - (wait this can take a long time) if fails - retry


NOTE!!!

the parameters names using "send" and "receive" are named to be consistent with the GTP DR Strategy meaning we "Send" (primary) West Europe, and "Receive" (DR) East US
This is actually the "reverse" of the flow of data in this script (since it's purpose is to "revert") but naming it this way allows parameters to be consistent with other 
DR scripts!



.PARAMETER sendAuthServiceURL
Auth Service for Primary Site

.PARAMETER $sendClientServiceURL
Client Service for Primary Site

.PARAMETER sendkeyVault
Keyvault on the Primary Site

.PARAMETER sendResourceGroupName
Resource Group on Primary Site

.PARAMETER receiveAuthServiceURL
Auth Service for DR Site

.PARAMETER $receiveClientServiceURL
Client Service for DR Site

.PARAMETER receivekeyVault
Keyvault on the DR Site

.PARAMETER receiveResourceGroupName
Resource Group on DRSide

.PARAMETER capellaClientId
Client Id for Capella Client - defaults to zero for environments without Capella

.PARAMETER TargetEmail
Email to use for Invitation

.PARAMETER capellaSubscriptionId
Subscription Id for Capella Client - defaults to zero for environments without Capella (empty for non Cappella env)

.PARAMETER capellaSendResourceGroupName
Resource Group for Capella Primary Client - defaults to zero for environments without Capella (empty for non Cappella env)

.PARAMETER capellaReceiveResourceGroupName
Resource Group for Capella DR Client - defaults to zero for environments without Capella (empty for non Cappella env)

.Example 
.\New-FailbackGTPDataSharesForExistingClients.ps1 -sendAuthServiceURL 'https://userservice-dev.sbp.eyclienthubd.com/' -sendClientServiceURL 'https://euwdgtp005wap0w.azurewebsites.net/'  `
	-sendkeyVault 'EUWDGTP005AKV01' -sendResourceGroupName 'GT-WEU-GTP-TENANT-DEV-RSG' `
	-receiveAuthServiceURL 'https://userservice-eus-dev.sbp.eyclienthub.com' -receiveClientServiceURL 'https://USEDGTP004WAP1K.azurewebsites.net'  -receivekeyVault 'USEDGTP004AKV01' `
	-receiveResourceGroupName  "GT-EUS-GTP-TENANT-DEV-RSG" -capellaClientId 136 -capellaSubscriptionId "e58114f4-8673-4cae-a138-80855cff70d9" -capellaReceiveResourceGroupName "GT-EUS-GTP-TENANT-CAPELLA-DEV-RSG" 
}

#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True)]
	[string] $sendAuthServiceURL,
	[Parameter(Mandatory = $True)]
	[string] $sendClientServiceURL,
	[Parameter(Mandatory = $True)]
	[string]$sendkeyVault,
	[Parameter(Mandatory = $True)]
	[string]$sendResourceGroupName,
	[Parameter(Mandatory = $True)]
	[string] $receiveAuthServiceURL,
	[Parameter(Mandatory = $True)]
	[string] $receiveClientServiceURL,
	[Parameter(Mandatory = $True)]
	[string]$receivekeyVault,
	[Parameter(Mandatory = $True)]
	[string]$receiveResourceGroupName,
	[Parameter(Mandatory = $false)]
	[string]$capellaClientId = 0,
	[Parameter(Mandatory = $false)]
	[string]$targetEmail = "A1232105-MSP01@EY.NET",
	[Parameter(Mandatory = $false)]
	[string]$capellaSubscriptionId = "",
	[Parameter(Mandatory = $false)]
	[string]$capellaSendResourceGroupName = "",
	[Parameter(Mandatory = $false)]
	[string]$capellaReceiveResourceGroupName = ""
)

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$connString = (Get-AzKeyVaultSecret -VaultName $sendkeyVault -Name 'connectionstring-clientdb').SecretValueText;

$clientConfigs = Get-ClientConfiguration -AuthService $sendAuthServiceURL   -ClientService $sendClientServiceURL  -KeyVault  $sendkeyVault
#iterate thrugh cients
foreach ($tenant in $clientConfigs) {
	$clientId = $tenant.clientId;

	Write-Output "processing client $ClientId "
	#skip if not a DR client
	if ($tenant.client.clientProfile.isDR -ne "Yes") {
		Write-Output "Client: $clientId not marked for DR, skipping";
		continue;
	}

	$existingADS = $tenant.clientServiceConfigurations | where { $_.resourceTypeId -eq 8 };
	if ($existingADS.Count -eq 0) {
		Write-Output "Client: $clientId missing ADS for send";
		continue;
	}

	
	# get subscription information
	if ($clientId -ne $capellaClient) {
		$SQL = "SELECT s.AzureSubscriptionId
					FROM  common.ClientSubscription cs
					INNER JOIN Common.Subscription s ON cs.SubscriptionID = s.SubscriptionId
					WHERE cs.ClientId = $clientId
					"
		$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    
		try {
			$sqlConnection.ConnectionString = $connString
			$sqlConnection.Open();

			$cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
			$reader = $cmd.ExecuteReader();
			$res = $reader.Read();
			if ($res -eq $false) {
				Write-Output "ERROR-UNABLE TO resset $clientId because no subscription information is available";
				continue;
			}

			$subscriptionId = $reader.GetString($reader.GetOrdinal("AzureSubscriptionId"));
			$useReceiveResourceGroupName = $receiveResourceGroupName;
			$useSendResourceGroupName = $sendResourceGroupName 
			
			$sqlConnection.Close();
		}
		Catch {
			Throw $_
		}
	}
	else {
		$subscriptionId = $capellaSubscriptionId;
		$useReceiveResourceGroupName = $capellaReceiveResourceGroupName;
		$useSendResourceGroupName = $capellaSendResourceGroupName
			
	}

	$receiveClientConfig = Get-ClientConfiguration -AuthService $receiveAuthServiceURL -ClientService $receiveClientServiceURL -KeyVault  $receivekeyVault -ClientId $clientId

	Set-AzContext -SubscriptionId $subscriptionId
	#datashare info from "send" side
	$sendDataShareAccountName = $existingADS[0].StorageAccount;
	$sendShareStorageAccountName = $tenant.storageAccounts[0].storageAccount;

	$existingReceiveADS = $receiveClientConfig.clientServiceConfigurations | where { $_.resourceTypeId -eq 8 };
	if ($existingReceiveADS.Count -eq 0)
	{
		write-output "missing ADS for Receive"
		continue;
	}
	$receiveDataShareAccountName =  $existingReceiveADS[0].storageAccount;
	$receiveShareStorageAccountName = $receiveClientConfig.storageAccounts[0].storageAccount;


.\New-FailbackGTPDataSharesForClient.ps1 -subscriptionId $subscriptionId -receiveResourceGroupName  $useReceiveResourceGroupName `
	-receiveDataShareAccountName  $receiveDataShareAccountName -origReceiveShareName "DRReceiveShare" -newReceiveShareName "DRFailbackSend" -receiveStorageAccountName $receiveShareStorageAccountName `
	-TargetEmail  $targetEmail -intClientID  $clientId -sendResourceGroupName $useendResourceGroupName -sendDataShareAccountName  $sendDataShareAccountName `
	-sendShareName  "DRFailbackReceive" -sendstorageAccountName $sendShareStorageAccountName
}
