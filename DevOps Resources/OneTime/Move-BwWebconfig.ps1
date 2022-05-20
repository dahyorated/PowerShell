<#
.SYNOPSIS
This script obtains the secret for a configuration service.

.DESCRIPTION
This script obtains the secret for the -SecretName from the key vault (-KeyVaultName).
The script assumes that the New-KVSecret.ps1 script resides in the same folder ($PSScriptRoot) as this script.

.PARAMETER AppSvcName
This is the key vault to search.

.PARAMETER ConfigAppService
This is the app service for the config service.

.Parameter Debugging
If this switch is specified, an existing key vault entry is ignored.

.EXAMPLE
Get-ConfigServiceSecret -KeyVaultName EUWDGTP005AKV01 -ConfigAppService EUWDGTPSHRWAP02

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]  
    [string]$AuthService,
    [Parameter(Mandatory=$true)]  
    [string]$ClientService,
    [Parameter(Mandatory=$true)]  
    [string]$ServiceID,
    [Parameter(Mandatory=$true)]  
    [string]$ServiceAuthSecret,
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    [Parameter(Mandatory=$true)]
    [ValidateSet('DEV', 'QA', 'UAT', 'PERF', 'DEMO', 'STG', 'PROD')]
    [string]$Environment,
    [Parameter(Mandatory=$false)]
    [string[]]$SubscriptionNames = @('EY-CTSBP-NON-PROD-TAX-GTP TENANT-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-01-39861197', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-02-39861197'),
    [Parameter(Mandatory=$false)]
    [string]$AppServiceName = ''

)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; 

function Move-FileToWebApp($resourceGroupName, $webAppName, $localPath, $kuduPath = ""){

    $kuduApiAuthorisationToken = GetKuduApiAuthorizationToken $webAppName $resourceGroupName;
    $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath";
    
    Write-Output "Copying $kuduPath to $kuduApiUrl";
    
    $repsonse = Invoke-RestMethod -Uri $kuduApiUrl `
                        -Headers @{"Authorization"=$kuduApiAuthorisationToken.token;"If-Match"="*"} `
                        -Method PUT `
                        -InFile $localPath `
                        -ContentType "multipart/form-data";

}


function GetKuduApiAuthorizationToken($appServiceName , $ResourceGroupNameTenant) { 

    if (  $null -eq  $Script:kuduCredsObject  ) {
        Write-Output "Getting kudo credentials";
        # get kudu login credentials
        $resourceType = "Microsoft.Web/sites/config" ; 
        $resourceName = "$appServiceName/publishingcredentials"; 
        Write-Output $resourceName;
        $publishingCredentials = Invoke-AzResourceAction -ResourceGroupName $ResourceGroupNameTenant -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2015-08-01 -Force; 
        # Write-Host $publishingCredentials;

        $Script:kuduCredsObject = @{};
        $un = $publishingCredentials.Properties.PublishingUserName ; 
        $pw = $publishingCredentials.Properties.PublishingPassword ; 
        $Script:kuduCredsObject.un = $un;
        $Script:kuduCredsObject.pw = $pw;
        $creds =  ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $un,$pw)))) ; 
        # Write-Host $creds;
        $Script:kuduCredsObject.token = $creds;
    }
    return $Script:kuduCredsObject;
}

$serviceBearerToken = "";

function authenticateAndGetClientConfigs() {

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #todo echo parms
    Write-Output "Getting Client Configurations for  ServiceID $ServiceID AuthService $AuthService ClientService $ClientService";
    
    # Get service auth token
    $serviceLogin = @{
        serviceId = $ServiceID
        secret    = $ServiceAuthSecret
    }
    # Specify we only need a short-lived token
    $headers = @{
        "X-Token-Expiration-Minutes" = "15"
        "Accept"                     = "application/json"
        "Content-Type"               = "application/json"
    }
    Write-Output  "Getting token from AuthService";
    $response = Invoke-RestMethod -Method Post -Uri "$AuthService/api/v1/authenticate/service" -Body (ConvertTo-Json $serviceLogin) -Headers $headers -ContentType "application/json"
    $token = $response.token
    $Script:serviceBearerToken = $token;
    
    return $clientConfigs
}

function getClientAppServices() {

    # get connection string to client DB either from KeyVault or from client routing service
    # create collection of Subscription / Client cross reference objects
    $authHeaders = @{
        Authorization = "Bearer $Script:serviceBearerToken"
        "Accept"      = "application/json"
    } ; 
    $platformConfigUrl =  "$ClientService/api/configuration";
    $platformConfigs = Invoke-RestMethod -Method Get -Uri $platformConfigUrl -Headers $authHeaders ; 

    $clientDbConfigObject = $platformConfigs.platformDatabases |  Where-Object {$_.service -eq "clientservice" } ; 

    $clientSubscription_SQL = "
                    SELECT [ClientServiceConfigurationId]
                    ,[ClientConfigId]
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
                    ,[UpdatedDtm]
                FROM [Common].[ClientServiceConfiguration]
                where [Service] in ('boardwalk', 'bwapods')
                and ResourceTypeId = 3
                and AccountName is not NULL 
    ";

    $clientSubDataTable = Invoke-Sqlcmd -Password $clientDbConfigObject.password -Username $clientDbConfigObject.username -Database $clientDbConfigObject.database -ServerInstance $clientDbConfigObject.server -Query $clientSubscription_SQL;

    $clientSubObjects = @() ; 
    ForEach ($Row in $clientSubDataTable)
    {
        $Properties = @{}
        For($i = 0;$i -le $Row.ItemArray.Count - 1;$i++)
        {
            $Properties.Add($clientSubDataTable[0].Table.Columns[$i], $Row.ItemArray[$i])
        }
        $clientSubObjects += New-Object -TypeName PSObject -Property $Properties  
    }
    return $clientSubObjects;

}

$fileName = Split-Path -Path $FilePath -Leaf -Resolve;

if($AppServiceName -eq '')
{
    authenticateAndGetClientConfigs ;
    $clientAppServices = getClientAppServices ;
    Write-Output "Found $($clientAppServices.length) BW app services to process...";
    #Get filename for FilePath

    $subProcessedInfo = @{};
    $appServicedProcessInfo = @{};

    foreach($subscription in $SubscriptionNames){
        $proccessedAppservices = 0;

        Set-AzContext $subscription;

        # This is the loop that does the work
        foreach ($clientApp in $clientAppServices) { 

            $Script:kuduCredsObject = $null ; # reset the Kudu creds 
            try {

                if($clientApp.AccountName.StartsWith("EUW") -or $clientApp.AccountName.StartsWith("euw")) {
                    $resourceGroupName = 'GT-WEU-GTP-TENANT-{0}-RSG'  -f $Environment;
                } else {
                    $resourceGroupName = 'GT-EUS-GTP-TENANT-{0}-RSG' -f $Environment;
                }
                $foundAppService = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $clientApp.AccountName -ErrorAction Stop;
                            
                Move-FileToWebApp -resourceGroupName $resourceGroupName -webAppName $foundAppService.Name -localPath $FilePath -kuduPath $fileName;
                $proccessedAppservices++;
                if($appServicedProcessInfo.ContainsKey($foundAppService.Name)){
                    $appServicedProcessInfo[$foundAppService.Name] = $true;
                }else {
                    $appServicedProcessInfo.Add($clientApp.AccountName, $true);
                }
            }
            catch {
                
                if($appServicedProcessInfo.ContainsKey($clientApp.AccountName) -eq $false){
                    $appServicedProcessInfo.Add($clientApp.AccountName, $false);
                }
            }
        }

        $subProcessedInfo.Add($subscription, $proccessedAppservices);
    }

    #Write out info
    foreach($infoKey in $subProcessedInfo.Keys) {
        Write-Output "Processed $($subProcessedInfo[$infoKey]) in $infoKey";
    }

    foreach($infoKey in $appServicedProcessInfo.Keys) {
        if($appServicedProcessInfo[$infoKey] -eq $false) {
            Write-Output "Failed to prcocess $infoKey";
        }
    }

    Write-Output "Total number of clients: $($clientAppServices.length)";
} else {
    
    foreach($subscription in $SubscriptionNames){
        
        Set-AzContext $subscription;

        try {
            Write-Output $AppServiceName;
            
            if($AppServiceName.StartsWith("EUW") -or $AppServiceName.StartsWith("euw")) {
                $resourceGroupName = 'GT-WEU-GTP-TENANT-{0}-RSG'  -f $Environment;
            } else {
                $resourceGroupName = 'GT-EUS-GTP-TENANT-{0}-RSG' -f $Environment;
            }

            $foundAppService = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $AppServiceName -ErrorAction Stop;
            Move-FileToWebApp -resourceGroupName $resourceGroupName -webAppName $foundAppService.Name -localPath $FilePath -kuduPath $fileName;
        }
        catch {
            Write-Output "Failed to find $AppServiceName in $subscription";
        }
    }
}
