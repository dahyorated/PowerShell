<#
.SYNOPSIS
This script is used to create new Cosmos DB Containers for existing clients.
It assumes the database has previously been created for the client

.DESCRIPTION
This script will get a list of tenants from the Client Service, and check if there's already a container for an existing service.
If not, it will create the container and routing database entry for the new container


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

.PARAMETER ResourceGroupName
Resource Group Name for the Core Cosmos DB

.PARAMETER kv
Azure Keyvault

.PARAMETER serviceName
The name of the service in routing - will also be container name created

.PARAMETER partitionKey
The partion key for the Cosmos DB container being created

.PARAMETER capellaClient
Client id for Capella.  Only relevant for Dev, UAT and Prod.  Capella client is in a seperate subscription
Defaults to 0 for environments with no capella

.PARAMETER capellaSubscriptionId 
Subscription id for the Capella Cosmos DB
defaults to empty string for environments with no capella

.PARAMETER capellaCosmosAccount
Name of Cosmos DB Account for Capella Client for environments with no capella

.PARAMETER capellaResourceGroupName
Resource Group Name for the Capella Cosmos DB for environments with no capella

.PARAMETER throughput
The CosmosDB throughput setting for thd container (default to 400)

.PARAMETER loadModule
If true Load Cosmos DB module - necessary for Pipelines but causes error for developers

.Example 
.\New-CosmosContainerForExistingClients.ps1 -subscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -authServiceURL "https://userservice-dev.sbp.eyclienthubd.com" -clientServiceURL "https://EUWDGTP005WAP0W.azurewebsites.net" `
	-drAccount "euwdgtp005cdb01" -noDRAccount "euwdgtp005cdb01" -resourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -kv "EUWDGTP005AKV01" -serviceName "snidermantestservice" -partionKey "/id" `
	-capellaClient 136 -capellaSubscriptionId "e58114f4-8673-4cae-a138-80855cff70d9" -capellaCosmosAccount "euwdgtp136cdb03" -capellaResourceGroupName "GT-WEU-GTP-TENANT-CAPELLA-DEV-RSG" -loadModule $false
#>


[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)]
    [string]$subscriptionId,
    [Parameter(Mandatory=$True)]
    [string]$authServiceURL,
    [Parameter(Mandatory=$True)]
    [string]$clientServiceURL,
    [Parameter(Mandatory=$True)]
    [string]$drAccount,
    [Parameter(Mandatory=$True)]
    [string]$noDRAccount,
    [Parameter(Mandatory=$True)]
    [string]$resourceGroupName,
    [Parameter(Mandatory=$True)]
    [string]$kv,
    [Parameter(Mandatory=$True)]
    [string]$serviceName,
    [Parameter(Mandatory=$True)]
    [string]$partionKey,
    [Parameter(Mandatory=$False)]
    [string]$capellaClient = 0,
    [Parameter(Mandatory=$False)]
    [string]$capellaSubscriptionId = "",
    [Parameter(Mandatory=$False)]
    [string]$capellaCosmosAccount = "",
    [Parameter(Mandatory=$False)]
    [string]$capellaResourceGroupName = "",
    [Parameter(Mandatory=$False)]
    [string]$throughput = 400,
    [Parameter(Mandatory=$False)]
    [bool]$loadModule = $true 
)


function new-GTPcosmosdbContainer {
    [CmdletBinding()]
    param(
        [string]$subscriptionId,
        [string]$account,
        [string]$clientId,
        [string]$kv,
        [string]$serviceName,
        [string]$partitionKey,
        [string]$throughput
    )
    
    #set context
    $res = Set-AzContext -SubscriptionId $subscriptionId
    $clientNum = ([string]$clientId).PadLeft(5, '0')

    $databaseName = $account + $clientNum + "cdb"

    #get the primary key
    $secretName = "primaryMasterKey" + $account;

    $primaryKey = (Get-AzKeyVaultSecret -VaultName $kv -Name $secretName).SecretValue;
    $cosmosDbContext = New-CosmosDbContext -Account $account -Database $databaseName -Key $primaryKey;

    #create user (once per client/database)
    $userId = $databaseName + "user";
    try
    {
    $collectionName = $serviceName
    Write-Output "Creating Collection $collectionName for databaseName $databaseName"; 
    $coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput $throughput
    $persmissionName = $userId + "permission" + $collectionName 
    $collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
    Write-Output "creating Permission: $persmissionName";
    $perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
    }
    catch {
        Write-Output $_.message
    }
}
  
function Update-GTPRouting {
    [CmdletBinding()]
    param(
        [int] $clientid,
        [string]  $account,
        [string] $kv,
        [string] $serviceName
    )

    $clientNum = ([string]$clientId).PadLeft(5, '0')


    $sql = "DECLARE @clientNum VARCHAR(5) = '$clientNum'
    DECLARE @accountName nvarchar(100) = '$account'
    Declare @resourceUrl nvarchar(100) = 'https://' + @accountName + '.documents.azure.com:443/'
    Declare @databaseName nvarchar(100) = @accountName + @clientNum +  'cdb'
    Declare @clientid bigint = $clientId 
    
    INSERT INTO [Common].[ClientServiceConfiguration]
               ([ClientConfigId]
               ,[Service]
               ,[ResourceTypeId]
               ,[AccountName]
               ,[ResourceURL]
               ,[Container]
               ,[Database]
               ,[Server]
               ,[Username]
               ,[IsProvisioned]
               ,[IsRequired]
               ,[IsFailed]
               ,[ErrorMessage]
               ,[ErrorCd]
               ,[GTPRecordStatusId]
               ,[IsDeleted]
               ,[CreatedUser]
               ,[CreatedDtm]
               ,[UpdatedUser]
               ,[UpdatedDtm])
         select
               cc.ClientConfigId
               ,'$serviceName'
               ,6
               ,@accountName
               ,@resourceUrl
               ,'$serviceName'
               ,@databaseName
               ,null
               ,NULL
               ,1
               ,1
               ,0
               ,null
               ,0
               ,1
               ,0
               ,'script'
               ,GETUTCDATE()
               ,'script'
               ,GETUTCDATE()
        FROM  Common.ClientConfiguration cc 
            WHERE cc.ClientId = @clientid
           
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
        $message = $_.Exception.Message;
        Stop-ProcessError $message;
    }
}
   
#main script
Write-Output "Starting New-CosmosContainerForExistingClients.ps1"

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

write-output "Installing module if needed"
if ($loadModule -eq $true -and -not (get-module -name "cosmosdb")) {
    install-packageprovider -name nuget -force -scope currentuser
    install-module -name cosmosdb -force -scope currentuser
}

write-output "Get Configuration AuthService $authServiceURL ClientService $clientServiceURL Keyvault $kv"
#get the configuration
$clientConfigs = Get-ClientConfiguration -AuthService $authServiceURL   -ClientService $clientServiceURL  -KeyVault  $kv

foreach ($tenant in $clientConfigs ) {

    #main SB script
    $clientId = $tenant.clientId;
    write-output "clientId: $clientid";
    [array] $existingContainer = $tenant.clientServiceConfigurations | where { ($_.resourceTypeId -eq 6 -and $_.service -eq $serviceName ) };
    if ($existingContainer.Count -gt 0) {
        Write-Output "Container for service $serviceName already exists";
        continue;
    }
    
    if ($clientId -eq $capellaClient) {
        $useAccount = $capellaCosmosAccount;
        $useSubscriptionId = $capellaSubscriptionId;
        $useResourceGroupName = $capellaResourceGroupName
    }
    else {
        $useSubscriptionId = $subscriptionId;
        $useResourceGroupName = $resourceGroupName
    }
   
    if ($tenant.client.clientProfile.isDR -eq "Yes") {
        $useAccount = $drAccount;
    }
    else {
        $useAccount = $noDRAccount;
    }

    write-output "Creating Cosmos Container for Account: $useAccount ClientId: $clientId Keyvault: $kv ServiceName $serviceName PartitionKey $partitionKey Throughput $throughput";
    new-GTPcosmosdbContainer -subscriptionId $useSubscriptionId -account $useAccount -clientId $clientId -kv $kv -serviceName $serviceName -partitionKey $partitionKey -throughput $throughput
  
    write-output "Updating Routing";
    Update-GTPRouting -clientid $clientId -account $useAccount -kv $kv -serviceName $serviceName;

    write-output "Completed migration for ClientId: $clientId";
}

Write-Output "Finishing New-CosmosContainerForExistingClients.ps1"

#script