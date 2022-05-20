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



$sb = {
    param($tenant,
        $drAccount,
        $noDRAccount,
        $kv,
        $subscriptionId,
        $cmdPath,
        $resourceGroupName,
        $temporaryFilePath 
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


        #create the database
        $db = New-CosmosDbDatabase -Context $cosmosDbContext -Id $databaseName;


        #create user (once per client/database)
        $userId = $databaseName + "user";
        Write-Output "Creating User: $userId";
        $user = New-CosmosDbUser -Context $cosmosDbContext -Id $userId;

        #iterate through collections - one per service within the client

        #collection documentservice - throughput at 10000 for migration - will be lowered to 400 after migration
        $collectionName = "documentservice"
        $partionKey = "/provider/id"
        Write-Output "Creating Collection $collectionName"; 
        $coll = New-CosmosDbCollection -Context $cosmosDbContext -Id $collectionName -PartitionKey $partionKey -OfferThroughput 10000
        $persmissionName = $userId + "permission" + $collectionName 
        $collectionId = Get-CosmosDbCollectionResourcePath -Database $databaseName -Id $collectionName
        Write-Output "creating Permission: $persmissionName";
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
        $clientNum = ([string]$clientId).PadLeft(5, '0')

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
            [string] $fromAccount,
            [string]$toAccount,
            [string]$kv,
            [string]$clientId,
            [string]$temporaryFilePath
        )

        $clientNum = ([string]$clientId).PadLeft(5, '0')
        $toDatabaseName = $toAccount + $clientNum + "cdb"

        $fromDocument1Name = "EY_GTP_Services_Document"
        $fromCollection1Name = "EY.GTP.Services.Document.Core.Domain.Resources.AuditDocument";

        $secretName = "primaryMasterKey" + $fromAccount;
        $fromPrimaryKey = (Get-AzKeyVaultSecret -VaultName $kv -Name $secretName).SecretValueText;

        $mongoConnectionString1 = "mongodb://" + $fromAccount + ":" + $fromPrimaryKey + "@" + $fromAccount + ".documents.azure.com:10255/" + $fromDocument1Name + "/?ssl=true";
        $fromDocument2Name = "EY_GTP_Services_WorkProducts"
        $fromCollection2Name = "EY.GTP.Services.Deliverable.Library.DTO.V1.WorkProduct";

        $mongoConnectionString2 = "mongodb://" + $fromAccount + ":" + $fromPrimaryKey + "@" + $fromAccount + ".documents.azure.com:10255/" + $fromDocument2Name + "/?ssl=true";


        $secretName = "primaryMasterKey" + $toAccount;
        $toPrimaryKey = (Get-AzKeyVaultSecret -VaultName $kv -Name $secretName).SecretValueText;
        $toCollection1Name = "documentservice";

        $toConnectionString = "AccountEndpoint=https://" + $toAccount + ".documents.azure.com:443/;AccountKey=" + $toPrimaryKey + ";Database=" + $toDatabaseName;

        $toCollection2Name = "workproductservice"

        $parms1 = " /s:MongoDB /s.ConnectionString:" + $mongoConnectionString1 + " /s.Collection:" + $fromCollection1Name + " /t:DocumentDB /t.ConnectionString:" + "`"" + $toConnectionString + "`"" + `
            " /t.Collection:" + $toCollection1Name + " /t.IdField:_id /t.CollectionThroughput:1000 /t.DisableIdGeneration:true" ;

        $out = Start-Process -FilePath $cmdPath -ArgumentList $parms1 -Wait -RedirectStandardOutput $temporaryFilePath
        write-output $out;

        $parms2 = " /s:MongoDB /s.ConnectionString:" + $mongoConnectionString2 + " /s.Collection:" + $fromCollection2Name + " /t:DocumentDB /t.ConnectionString:" + "`"" + $toConnectionString + "`"" + `
            " /t.Collection:" + $toCollection2Name + " /t.IdField:_id /t.CollectionThroughput:1000 /t.DisableIdGeneration:true" ;
        
        $file2 = $temporaryFilePath + "2";
        $out = Start-Process -FilePath $cmdPath -ArgumentList $parms2 -Wait  -RedirectStandardOutput $file2
        write-output $out;

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
   
    write-output "main script block for client executing";
    $ErrorActionPreference = "Stop"
    #main SB script
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

    write-output "Running Migration Utility for MongoAccount: $mongoAccount"
    Run-CosmosMigrationUtility -fromAccount $mongoAccount -toAccount $account -kv $kv -clientId $clientId -cmdPath $cmdPath -temporaryFilePath $temporaryFilePath; 

    write-output "Setting Throughput for ResourceGroup: $resourceGroupName"
    set-GTPComosDBThroughput -account $account -clientId $clientID -resourceGroupName $resourceGroupName;

    write-output "Updating Routing";
    Update-GTPRouting -clientid $clientId -account $account -kv $kv;

    write-output "Completed migration for ClientId: $clientId";
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
#iterate through each client
$i = 0;
$jobInfo = @{ };
foreach ($tenant in $clients) {
    write-output "checking if max jobs are running"
    $running = @(Get-Job | Where-Object { $_.State -eq 'Running' })
    if ($running.Count -ge 4) {
        $running | Wait-Job -Any | Out-Null
    }

    $i++;
    write-output "Starting job $i"
    $fileName = "MigrateOut" + $i + ".txt";
    [String]$temporaryFilePath = Join-Path $outFilePath $fileName; 
    $jobName = "Job" + $i;
    $jobInfo[$jobName] = $temporaryFilePath;

    Start-Job $sb -Name $jobName -ArgumentList  $tenant, $drAccount, $noDRAccount, $kv, $subscriptionId, $cmdPath, $resourceGroupName, $temporaryFilePath | Out-Null
}

Wait-Job * | Out-Null

# Process the results
write-output "getting results"
$i = 0;
foreach ($job in Get-Job) {
    $i++;
    write-output "getting output for job $i";
    $result = Receive-Job $job
    Write-Output $result
    #file won't exist if already converted so check for existance
    if (Test-Path $fileName) {
        write-output "conversion output"
        $fileName = $jobInfo[$job.Name];
        Write-Output (Get-Content $fileName);
        $file2 = $fileName + "2";
        Write-Output (Get-Content $file2);
        
        Remove-Item -Path $fileName;
        Remove-Item -Path $file2;
    }
}

Remove-Job -State Completed

    
#script
