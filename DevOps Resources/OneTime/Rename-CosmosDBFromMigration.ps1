#Install-Module -Name CosmosDB -Scope CurrentUser
<#
.SYNOPSIS
This script is for Release 9.5 Cosmos DB migration. 
 Cosmos is going from one Account per Tenant to two Accounts in Core (with databases per tenant).  One for Geo Replication and the other for Non DR Clients

.DESCRIPTION
This script will get a list of tenants from the Client Service, and check if it's been configured already for the new setup (this is true for clients in lower env's created with new provisioning)
If not, then it provision the Cosmos DB for the client and set permissions
Then migrate two containers from the tenant Account. 
Next the two containers that were migrated will reset throughput to desired value (set high to make the conversion run more efficiently)
Lastly, client routing is updated to indidate the new configuration

IMPORTANT!

The following is necessary for this to execute
1. Powershell Module "CosmosDB" must be installed
2. The Cosmos DB Migration Utility must be available at the path specified by parameter cmdPath
   https://aka.ms/csdmtool

.PARAMETER ResourceGroupName
Resource Group Name for the Core Cosmos DB

.PARAMETER subscriptionId
Subscription id for the Core Cosmos DB

.PARAMETER authServiceURL
Authentication (User Service) URL to get a GTP Service Token

.PARAMETER clientServiceURL
Client (Routing) Service URL to get the client configuration

.PARAMETER noDRAccount
Name of Cosmos DB Account for clients not replicating

.PARAMETER drAccount
Name of Cosmos DB Account for Clients replicating

.PARAMETER kv
Azure Keyvault

.PARAMETER cmdPath
Fully qualified path to the location of the Cosmos DB Migration Utility


.Example 
.\Create-CosmosDBForMigration.ps1 -subscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -authServiceURL "https://userservice-dev.sbp.eyclienthubd.com" -clientServiceURL "https://euwdgtp005wap0w.azurewebsites.net" -noDRAccount "euwdgtp005cdb01" -drAccount "euwdgtp005cdb02" -resourceGroupName  "GT-WEU-GTP-CORE-DEV-RSG" -kv "EUWDGTP005AKV01"

#>



param (
	[string]$account = "euwdgtp005cdb01",
	[string]$resourceGroupName = "GT-WEU-GTP-CORE-DEV-RSG",
	[string]$kv = "EUWDGTP005AKV01",
	[string]$cmdPath = "C:\Users\AV114DZ\Desktop\CosmosMigrate\dt.exe",
	[string]$subscriptionId="5aeb8557-cab7-41ac-8603-9f94ad233efc"
   )


function new-GTPcosmosdb {
	[CmdletBinding()]
	param(
		[string]$subscriptionId,
		[string]$account,
		[string]$clientId,
		[string]$kv
	)
	
	#set context
	$res = Set-AzContext -SubscriptionId $subscriptionId

	$clientNum = ([string]$clientId).PadLeft(5,'0')
	$databaseName = $account + $clientNum + "cdb"

	Write-Host "creating database $databaseName"

	#get the primary key
	$secretName = "primaryMasterKey" + $account;

	$primaryKey = (Get-AzKeyVaultSecret -VaultName $kv -Name $secretName).SecretValue;
	$cosmosDbContext = New-CosmosDbContext -Account $account -Database $databaseName -Key $primaryKey;


	#create the database
	$db = New-CosmosDbDatabase -Context $cosmosDbContext -Id $databaseName;

	#create user (once per client/database)
	$userId = $databaseName + "user";
	$user = New-CosmosDbUser -Context $cosmosDbContext -Id $userId;

	#iterate through collections - one per service within the client

	#collection documentservice - throughput at 10000 for migration - will be lowered to 400 after migration
	$collectionName = "documentservice"
	$partionKey = "/provider/id"
	$coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 10000
	$persmissionName = $userId + "permission" + $collectionName  
	$collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
	$perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
 

	#collection workproductservice  - throughput at 10000 for migration - will be lowered to 400 after migration
	$collectionName = "workproductservice"
	$partionKey = "/context/region/regionId"
	$coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 10000
	$persmissionName = $userId + "permission" + $collectionName 
	$collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
	$perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 

	#collection taskservice
	$collectionName = "taskservice"
	$partionKey = "/id"
	$coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 400
	$persmissionName = $userId + "permission" + $collectionName 
	$collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
	$perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 

	#collection workspaceservice
	$collectionName = "workspaceservice"
	$partionKey = "/id"
	$coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 400
	$persmissionName = $userId + "permission" + $collectionName 
	$collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
	$perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
}
function set-GTPComosDBThroughput {
	param(
		[string]$account,
		[string]$clientId,
		[string]$resourceGroupName
	)
	$clientNum = ([string]$clientId).PadLeft(5,'0')
	$databaseName = $account + $clientNum + "cdb"

	$collectionName = "documentservice"
		
	$apiVersion = "2015-04-08"
	$containerThroughputResourceName = $account + "/sql/" + $databaseName + "/" + $collectionName + "/throughput"
	$containerThroughputResourceType = "Microsoft.DocumentDb/databaseAccounts/apis/databases/containers/settings"
	$throughput = 400
	
	$properties = @{
		"resource" = @{"throughput" = $throughput }
	}
		
	$out = Set-AzResource -ResourceType $containerThroughputResourceType `
		-ApiVersion $apiVersion -ResourceGroupName $resourceGroupName `
		-Name $containerThroughputResourceName -PropertyObject $properties -Force

	$collectionName = "workproductservice"
	$containerThroughputResourceName = $account + "/sql/" + $databaseName + "/" + $collectionName + "/throughput"

	$out = Set-AzResource -ResourceType $containerThroughputResourceType `
		-ApiVersion $apiVersion -ResourceGroupName $resourceGroupName `
		-Name $containerThroughputResourceName -PropertyObject $properties -Force
	
}

function Run-CosmosMigrationUtility {
	[CmdletBinding()]
	param(
		[string] $cmdPath,
		[string] $account,
		[string]$kv,
		[string]$clientId 
	)

	$clientNum = ([string]$clientId).PadLeft(5,'0')    
	$fromDatabaseName = $account + $clientId + "cdb"
	$toDatabaseName = $account + $clientNum + "cdb"

	$secretName = "primaryMasterKey" + $account;
	$primaryKey = (Get-AzKeyVaultSecret -VaultName $kv -Name $secretName).SecretValueText;
	$fromConnectionString = "AccountEndpoint=https://" + $account + ".documents.azure.com:443/;AccountKey=" + $primaryKey + ";Database=" + $fromDatabaseName;
  
	$toCollection1Name = "documentservice";
	$toConnectionString = "AccountEndpoint=https://" + $account + ".documents.azure.com:443/;AccountKey=" + $primaryKey + ";Database=" + $toDatabaseName;

	$toCollection2Name = "workproductservice"

	$parms1 = " /s:DocumentDB /s.ConnectionString:" + "`"" + $fromConnectionString + "`"" + " /s.Collection:" + $toCollection1Name + " /t:DocumentDB /t.ConnectionString:" + "`"" + $toConnectionString + "`"" + `
		" /t.Collection:" + $toCollection1Name + " /t.IdField:_id /t.CollectionThroughput:1000 /t.DisableIdGeneration:true" ;

	$out = Start-Process -FilePath $cmdPath -ArgumentList $parms1 -Wait 
	Write-Host $out;

	$parms2 = " /s:DocumentDB /s.ConnectionString:" + "`"" + $fromConnectionString + "`"" + " /s.Collection:" + $toCollection2Name + " /t:DocumentDB /t.ConnectionString:" + "`"" + $toConnectionString + "`"" + `
		" /t.Collection:" + $toCollection2Name + " /t.IdField:_id /t.CollectionThroughput:1000 /t.DisableIdGeneration:true" ;

	$out = Start-Process -FilePath $cmdPath -ArgumentList $parms2 -Wait 
	Write-Host $out;

}

function Update-GTPRouting {
	[CmdletBinding()]
	param(
		[string] $clientId,
		[string]  $account,
		[string] $kv
	)

	$clientNum = ([string]$clientId).PadLeft(5,'0')
	$databaseName = $account + $clientNum + "cdb"

	#update sql to use new client id
	$sql = "UPDATE csc
	SET csc.[Database] = '$databaseName'
		FROM Common.ClientServiceConfiguration csc
		INNER JOIN Common.ClientConfiguration cc ON csc.ClientConfigId = cc.ClientConfigId
		WHERE csc.ResourceTypeId = 6
		AND cc.ClientId = $clientId 

		";
	
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

#main script

$ErrorActionPreference = "Stop"


#Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;

#get the configuration
#$clients = (99,136,242,243);
$clients = (136,242,243);


#iterate through each client
foreach ($clientId in $clients) {
	#change to use this client list

	Write-Host "Starting migration for ClientId: $clientId";

	Write-Host "Creating Cosmos DB for Account: $account ClientId: $clientId Keyvault: $kv"

	#create the database
	new-GTPcosmosdb -SubscriptionId $subscriptionId -Account $account -clientId $clientId -kv $kv

	Write-Host "Running Migration Utility for account: $account"
	Run-CosmosMigrationUtility -account $account -kv $kv -clientId $clientId -cmdPath $cmdPath; 

	Write-Host "Setting Throughput for ResourceGroup: $resourceGroupName"
	set-GTPComosDBThroughput -account $account -clientId $clientID -resourceGroupName $resourceGroupName;

	Write-Host "Updating Routing";
	Update-GTPRouting -clientId $clientId -account $account -kv $kv;

	Write-Host "Completed migration for ClientId: $clientId";
}

#script
