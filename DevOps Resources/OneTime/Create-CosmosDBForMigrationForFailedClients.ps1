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

.PARAMETER capellaClient
Client id of Capella - for now skipping - may need a 1-off

.PARAMETER  outFilePath
Path name of directory to store temporary file for output from migration utility.

.Example 
.\Create-CosmosDBForMigration.ps1 -subscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -authServiceURL "https://userservice-dev.sbp.eyclienthubd.com" -clientServiceURL "https://euwdgtp005wap0w.azurewebsites.net" -noDRAccount "euwdgtp005cdb01" -drAccount "euwdgtp005cdb02" -resourceGroupName  "GT-WEU-GTP-CORE-DEV-RSG" -kv "EUWDGTP005AKV01"

#>




[CmdletBinding()]
param (
    [string]$subscriptionId,
    [string]$authServiceURL,
    [string]$clientServiceURL,
    [string]$noDRAccount,
    [string]$drAccount,
    [string]$resourceGroupName,
    [string]$kv,
    [string]$cmdPath = "C:\Users\AV114DZ\Desktop\CosmosMigrate\dt.exe",
    [string]$capellaClient = 0,
    [string]$outFilePath = "C:\file13"
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
    $clientNum = ([string]$clientId).PadLeft(5, '0')

    $databaseName = $account + $clientNum + "cdb"
    write-output "Creating Cosmos DB: $databaseName";

    #get the primary key
    $secretName = "primaryMasterKey" + $account;

    $primaryKey = (Get-AzKeyVaultSecret -VaultName $kv -Name $secretName).SecretValue;
    $cosmosDbContext = New-CosmosDbContext -Account $account -Database $databaseName -Key $primaryKey;

     
    #create user (once per client/database)
    $userId = $databaseName + "user";
    Write-Output "Creating User: $userId if needed";
    $users = Get-CosmosDbUser -Context $cosmosDbContext
    if ($users -eq $null) {
        $user = New-CosmosDbUser -Context $cosmosDbContext -Id $userId;
    }

    #get collections
    $collections = Get-CosmosDbCollection -Context $cosmosDbContext

    #iterate through collections - one per service within the client

    #collection documentservice - throughput at 10000 for migration - will be lowered to 400 after migration
    $collectionName = "documentservice"
    $partionKey = "/provider/id"

    if (($collections | where-Object { $_.Id -eq $collectionName }) -eq $null) {
        Write-Output "Creating Collection $collectionName"; 
        $coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 400
        $persmissionName = $userId + "permission" + $collectionName 
        $collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
        Write-Output "creating Permission: $persmissionName";
        $perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
    }
    else {
        #set throughput
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

    }
 
    $collectionName = "workproductservice"
    if (($collections | where-Object { $_.Id -eq $collectionName }) -eq $null) {
        
        #collection workproductservice  - throughput at 10000 for migration - will be lowered to 400 after migration
        $partionKey = "/context/region/regionId"
        $coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 10000
        $persmissionName = $userId + "permission" + $collectionName 
        $collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
        $perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
    }
    else {
        $collectionName = "workproductservice"
        $containerThroughputResourceName = $account + "/sql/" + $databaseName + "/" + $collectionName + "/throughput"

        $out = Set-AzResource -ResourceType $containerThroughputResourceType `
            -ApiVersion $apiVersion -ResourceGroupName $resourceGroupName `
            -Name $containerThroughputResourceName -PropertyObject $properties -Force
    
    }
    #collection taskservice
    $collectionName = "taskservice"
    if (($collections | where-Object { $_.Id -eq $collectionName }) -eq $null) {
        $partionKey = "/id"
        $coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 400
        $persmissionName = $userId + "permission" + $collectionName 
        $collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
        $perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
    }
    #collection workspaceservice
    $collectionName = "workspaceservice"
    if (($collections | where-Object { $_.Id -eq $collectionName }) -eq $null) {
        $partionKey = "/id"
        $coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 400
        $persmissionName = $userId + "permission" + $collectionName 
        $collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
        $perm = New-CosmosDbPermission -Context $cosmosDbContext -UserId $userId -Id $persmissionName -Resource $collectionId -PermissionMode All 
    }

}
    
function Update-GTPRouting {
    [CmdletBinding()]
    param(
        [int] $clientid,
        [string]  $account,
        [string] $kv
    )

    $clientNum = ([string]$clientId).PadLeft(5, '0')


    $sql = "DECLARE @clientNum VARCHAR(5) = '$clientNum'
    DECLARE @accountName nvarchar(100) = '$account'
    Declare @resourceUrl nvarchar(100) = 'https://' + @accountName + '.documents.azure.com:443/'
    Declare @databaseName nvarchar(100) = @accountName + @clientNum +  'cdb'
    Declare @clientid bigint = $clientId 
    UPDATE csc 
        SET csc.AccountName = @accountName,
        csc.ResourceURL = @resourceUrl,
        csc.[Database] = @databaseName,
        csc.[Container] = 'workproductservice'
    FROM Common.ClientServiceConfiguration csc
    INNER JOIN Common.ClientConfiguration cc ON cc.ClientConfigId = csc.ClientConfigId
    WHERE cc.ClientId = @clientid
    and csc.ResourceTypeId = 6
    and csc.service = 'deliverable'
    
    UPDATE csc 
        SET csc.AccountName = @accountName,
        csc.ResourceURL = @resourceUrl,
        csc.[Database] = @databaseName,
        csc.[Container] = 'documentservice'
    FROM Common.ClientServiceConfiguration csc
    INNER JOIN Common.ClientConfiguration cc ON cc.ClientConfigId = csc.ClientConfigId
    WHERE cc.ClientId = @clientid
    and csc.ResourceTypeId = 6
    and csc.service = 'documentservice'
    
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
               ,'taskservice'
               ,6
               ,@accountName
               ,@resourceUrl
               ,'taskservice'
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
               ,'workspaceservice'
               ,6
               ,@accountName
               ,@resourceUrl
               ,'workspaceservice'
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
        Throw $_
    }
}
   
    
#main script

write-output "Installing module if needed"
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;


if (-not (get-module -name "cosmosdb")) {
    install-packageprovider -name nuget -force -scope currentuser
    install-module -name cosmosdb -force -scope currentuser
}

write-output "Get Configuration"
#get the configuration
$clientConfigs = Get-ClientConfiguration -AuthService $authServiceURL   -ClientService $clientServiceURL  -KeyVault  $kv

# Move the three checks here
write-output "Filtering out Capella Client";
$clients = $clientConfigs | Where-Object { $_.clientId -ne $capellaClient }
$ErrorActionPreference = "Stop"
#main SB script
foreach ($tenant in $clients) {
    $clientId = $tenant.clientId;
    write-output "clientId: $clientid";
    $cosmosResource = $tenant.clientServiceConfigurations | Where-Object -Property resourceTypeId -eq 6 | Select-Object -First 1;
    
    if (![string]::IsNullOrEmpty($cosmosResource.Container)) {
        write-output "ClientId: $clientId already converted, skipping";
        continue; 
    } 
    
    if ([string]::IsNullOrEmpty($cosmosResource.database)) {
        write-output "ERROR ClientId:  $clientId does not have a mongodb database - skipping";
        continue;
    }

    $mongoAccount = ($cosmosResource.database).ToLower();
    if ($tenant.client.clientProfile.isDR -eq "Yes") {
        $account = $drAccount;
    }
    else {
        $account = $noDRAccount;
    }

    write-output "Starting migration for ClientId: $clientId";

    write-output "Creating Cosmos DB for Account: $account ClientId: $clientId Keyvault: $kv"

    #create the database
    new-GTPcosmosdb -SubscriptionId $subscriptionId -Account $account -clientId $clientId -kv $kv

    write-output "Updating Routing";
    Update-GTPRouting -clientid $clientId -account $account -kv $kv;

    write-output "Completed migration for ClientId: $clientId";

}

    
#script
