
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True)]
	[string]$sendLocation,
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
	[string]$tenantId,
	[Parameter(Mandatory = $False)]
	[string]$capellaClient = 0,
	[Parameter(Mandatory = $False)]
	[string]$capellaSubscriptionId = "",
	[Parameter(Mandatory = $False)]
	[string]$capellaSendResourceGroupName = "",
	[Parameter(Mandatory = $False)]
	[string]$capellaReceiveResourceGroupName = "",   
	[Parameter(Mandatory = $False)]
	[string]$CapellaSPNName = "",
	[Parameter(Mandatory = $False)]
	[string]$CapellaSPNId = "",
	[Parameter(Mandatory = $False)]
	[string]$CapellaOmsWorkSpaceId = "",
	[Parameter(Mandatory = $False)]
	[string]$CapellaOmsWorkSpaceResourceGroup = "",
	[Parameter(Mandatory = $False)]
	[string]$CapellaOmsWorkSpaceName = "",
	[Parameter(Mandatory = $False)]
	[int]$startClientId = 0,
	[Parameter(Mandatory = $False)]
	[int]$endClientId= 999999
)

$ErrorActionPreference = "Stop"; 

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
   

if (-not (get-module -ListAvailable -name "Az.DataShare")) {
    install-packageprovider -name nuget -force -scope currentuser
    install-module -name "Az.DataShare" -force -scope currentuser
}

$connString = (Get-AzKeyVaultSecret -VaultName $sendkeyVault -Name 'connectionstring-clientdb').SecretValueText;
			
write-output "Get Configuration"
$clientConfigs = Get-ClientConfiguration -AuthService $sendAuthServiceURL   -ClientService $sendClientServiceURL  -KeyVault  $sendkeyVault
#iterate thrugh cients
foreach ($tenant in $clientConfigs) {
	$clientId = $tenant.clientId;
	if ($clientId -lt $startClientId -or $clientId -gt $endClientId)
	{
		continue;
	}

	Write-Output "processing client $ClientId "
	#skip if not a DR client
	if ($tenant.client.clientProfile.isDR -ne "Yes") {
		Write-Output "Client: $clientId not marked for DR, skipping";
		continue;
	}

	#skip if already migrated
	$existingADS = $tenant.clientServiceConfigurations | where { $_.resourceTypeId -eq 8 };
	if ($existingADS.Count -gt 0) {
		Write-Output "Client: $clientId already converted";
		continue;	
	}

	#next get subscription data for Non Capella
	if ($clientId -ne $capellaClient) {
		$SQL = "SELECT s.*
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
				Write-Output "ERROR-UNABLE TO MIGRATE Client $clientId because no subscription information is available";
				$sqlConnection.Close();
				continue;
			}

			$subscriptionId = $reader.GetString($reader.GetOrdinal("AzureSubscriptionId"));
			$tenantId = $reader.GetString($reader.GetOrdinal("TenantId"));
			$SPNName = $reader.GetString($reader.GetOrdinal("SPNName"));
			$SPNId = $reader.GetString($reader.GetOrdinal("SPNId"));
			$OmsWorkSpaceId = $reader.GetString($reader.GetOrdinal("OmsWorkSpaceId"));
			$OmsWorkSpaceResourceGroup = $reader.GetString($reader.GetOrdinal("OmsWorkSpaceResourceGroup"));
			$OmsWorkSpaceName = $reader.GetString($reader.GetOrdinal("OmsWorkSpaceName"));
			$sendResourceGroup = $reader.GetString($reader.GetOrdinal("TenantPrimaryResourceGroupName"));
			$receiveResourceGroup =$reader.GetString( $reader.GetOrdinal("TenantSecondaryResourceGroupName"));

			$sqlConnection.Close();
		}
		Catch {
			Throw $_
		}
	}
	else {
		$subscriptionId = $capellaSubscriptionId;
		$sendResourceGroup = $capellaSendResourceGroupName;
		$receiveResourceGroup = $capellaReceiveResourceGroupName;

		$SPNName = $CapellaSPNName
		$SPNId = $CapellaSPNId
		$OmsWorkSpaceId = $CapellaOmsWorkSpaceId
		$OmsWorkSpaceResourceGroup = $CapellaOmsWorkSpaceResourceGroup
		$OmsWorkSpaceName = $CapellaOmsWorkSpaceName
	}

    
	. $PSScriptRoot\New-DataSharesForGTPClient -sendLocation 'westeurope' -clientId $clientId -sendResourceGroup $sendResourceGroup -invitationEmail $invitationEmail `
		-sendAuthServiceURL $sendAuthServiceURL -sendClientServiceURL $sendClientServiceURL -sendkeyVault $sendkeyVault -subscriptionId $subscriptionId `
		-DataShareFullPath $DataShareFullPath -receiveResourceGroup $receiveResourceGroup  -receiveLocation 'eastus' `
		-receiveAuthServiceURL $receiveAuthServiceURL -receiveClientServiceURL $receiveClientServiceURL -receivekeyVault $receivekeyVault `
		-SPNName $SPNName -SPNId $SPNId -OmsWorkSpaceId $OmsWorkSpaceId -OmsWorkSpaceResourceGroup $OmsWorkSpaceResourceGroup -OmsWorkSpaceName $OmsWorkSpaceName -tenantId $tenantId
	
}
	
