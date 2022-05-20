<#
.SYNOPSIS
Resets the Failback to "Normal" State for DR after Failback completes

.DESCRIPTION

1) For each DR Client:
2) Ensure ADS exists and get subscription information
3) Recreate the hourly "trigger" from West Europe to East US

NOTE!!!

the parameters names using "send" and "receive" are named to be consistent with the GTP DR Strategy meaning we "Send" (primary) West Europe, and "Receive" (DR) East US
This is actually the "reverse" of the flow of data in this script (since it's purpose is to "revert") but naming it this way allows parameters to be consistent with other 
DR scripts!


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

.PARAMETER capellaSubscriptionId
Subscription Id for Capella Client - defaults to zero for environments without Capella (empty for non Cappella env)

.PARAMETER capellaSendResourceGroupName
Resource Group for Capella Primary Client - defaults to zero for environments without Capella (empty for non Cappella env)

.PARAMETER capellaReceiveResourceGroupName
Resource Group for Capella DR Client - defaults to zero for environments without Capella (empty for non Cappella env)

.PARAMETER $receiveShareName
Share Name for the Receive

.PARAMETER $RecurrenceInterval
Interval for the Sync - defaults to Hour

.PARAMETER $SynchronizationTime
Date Time to start - really only looks at HH:MM

.Example 

.\Reset-DataSharesAfterFailback.ps1 -receiveAuthServiceURL 'https://userservice-eus-dev.sbp.eyclienthub.com'  -receiveClientServiceURL 'https://USEDGTP004WAP1K.azurewebsites.net' `
	-receivekeyVault 'USEDGTP004AKV01' 	-receiveResourceGroupName "GT-EUS-GTP-TENANT-DEV-RSG"  `
	-capellaClient 136 -capellaSubscriptionId "e58114f4-8673-4cae-a138-80855cff70d9" -capellaReceiveResourceGroupName "GT-EUS-GTP-TENANT-CAPELLA-DEV-RSG"

#>


[CmdletBinding()]
param (
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
	[string]$capellaSubscriptionId,
	[Parameter(Mandatory = $false)]
	[string]$capellaReceiveResourceGroupName = "",
	[Parameter(Mandatory = $false)]
	[string]$receiveShareName = "DRReceiveShare", 
	[Parameter(Mandatory = $false)]
	[ValidateSet("Hour", "Day")]
	[string]$RecurrenceInterval = "Hour",
	[Parameter(Mandatory = $false)]
	[string]$SynchronizationTime = "1/31/2020 17:00"
)

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
$connString = (Get-AzKeyVaultSecret -VaultName $receivekeyVault -Name 'connectionstring-clientdb').SecretValueText;

$clientConfigs = Get-ClientConfiguration -AuthService $receiveAuthServiceURL -ClientService $receiveClientServiceURL -KeyVault  $receivekeyVault
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
		Write-Output "Client: $clientId missing ADS";
		continue;
	}

	
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
			$resourceGroupName = $receiveResourceGroupName;
			
			$sqlConnection.Close();
		}
		Catch {
			Throw $_
		}
	}
	else {
		$subscriptionId = $capellaSubscriptionId;
		$resourceGroupName = $capellaReceiveResourceGroupName;
	}

	Set-AzContext -SubscriptionId $subscriptionId

	
	$receiveShareAccountName = $existingADS[0].storageAccount
	try {
		[array] $existingShare = Get-AzDataShareTrigger -ResourceGroupName $resourceGroupName -AccountName $receiveShareAccountName  -ShareSubscriptionName $receiveShareName
	}
	catch {
		#this doesn't work - for some reason Get-AzDataShareTrigger will write errors but not be "caught"
		Write-Output "Failure on Lookup for Trigger : $_";
		continue;
	}

	#per comment above see if resulting variable is null
	if ($existingShare -eq $null)
	{
		Write-Output "Failure on Lookup for Trigger";
		continue;
	}
	
	#If the Share exists, but not the Trigger - for some reason it comes as empty string not null...
	Write-Output "Checking DataShare $receiveShareAccountName"
	if ($existingShare.Count -eq 0) {
		Write-Output "enabling trigger";
		try {
			New-AzDataShareTrigger -ResourceGroupName $resourceGroupName  -AccountName $receiveShareAccountName -ShareSubscriptionName  $receiveShareName -Name Trigger -RecurrenceInterval $RecurrenceInterval -SynchronizationTime $SynchronizationTime
		}
		catch {
			Write-Output "Failed with message: $($_.Exception.Message)"
		}
	}
	else {
		Write-Output "Trigger already exists"
	}
}
