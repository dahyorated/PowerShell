<#
.SYNOPSIS
Verify a number of configurations for a Boardwalk client request

.DESCRIPTION
Script to verify app service, App Gateway Listener, Backend pool and Ruleset for a given set of clients.
Additionally, the user has an option to lockdown successfully verified app services on a client basis
Note: This script is intended to run in a console manually and not through a pipeline

.PARAMETER ClientIds
Array of client ids to confirm Boardwalk configuration

.PARAMETER StageName
Tenant resource group name

.PARAMETER TagName
Name of the tag to find an app service

.Example
.\Invoke-BoardwalkConfigValidationAndLockdown.ps1 -ClientIds @("1273", "1284") -StageName "PRD-EUW"

#>
   [CmdletBinding()]
   param (
       [Parameter(Mandatory=$true)]
       [string[]]$ClientIds = @(),
       [Parameter(Mandatory=$true)]
       [ValidatePattern('(DEV|QAT|UAT|DMO|PRF|STG|PRD)-(EUW|USE)')]
       [string]$StageName,
       [Parameter(Mandatory=$false)]
       [string]$TagName = "ROLE_PURPOSE"
   )

#functions
function Get-ClientSubInfo
{
	Param
    (
         [int]$clientId,
         [string]$connString
    )

    $clientInfoFromDb = New-Object System.Object;

	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection;
	$sqlConnection.ConnectionString = $connString;
	$sqlConnection.Open();
    #$sql = "SELECT ClientServiceConfigurationId, IsProvisioned from Common.ClientServiceConfiguration";
    #$sqlold = "select cs.ClientId, s.* from Common.Subscription s ";
    #$sqlold = $sqlold + "inner join Common.ClientSubscription cs ON s.SubscriptionId = cs.SubscriptionId ";
    #$sqlold = $sqlold + "where cs.ClientId = " + $clientId.ToString();

    $sql = "select cs.ClientId, csc.ResourceUrl, csc.AccountName as AppService, s.* from Common.Subscription s "; 
    $sql = $sql + "inner join Common.ClientSubscription cs ON s.SubscriptionId = cs.SubscriptionId ";
    $sql = $sql + "inner join Common.ClientConfiguration cc ON cc.ClientId = cs.ClientId "; 
    $sql = $sql + "inner join Common.ClientServiceConfiguration csc on csc.ClientConfigId = cc.ClientConfigId ";
    $sql = $sql + "where cs.ClientId = "  + $clientId.ToString() + " "; 
    $sql = $sql + "and cc.AzureRegionId = 1 ";
    $sql = $sql + "and csc.[Service] IN ('boardwalk','bwapods') ";
    $sql = $sql + "and csc.[ResourceTypeId] = 3 "; 
    $sql = $sql + "and csc.[IsProvisioned] = 1 ";


    $cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
    $rdrResults = $cmd.ExecuteReader(); 
    $exists = $rdrResults.Read();
    $value1 = $rdrResults["ClientId"];	
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "ClientId" -Value $rdrResults["ClientId"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "TenantSubscriptionName" -Value $rdrResults["SubscriptionName"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "AzureSubscriptionID" -Value $rdrResults["AzureSubscriptionID"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "TenantResourceGroupName" -Value $rdrResults["TenantPrimaryResourceGroupName"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "SpnName" -Value $rdrResults["SPNName"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "SpnId" -Value $rdrResults["SPNId"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "TenantId" -Value $rdrResults["TenantId"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "ResourceUrl" -Value $rdrResults["ResourceUrl"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "AppService" -Value $rdrResults["AppService"];
    $rdrResults.Close();
    $sqlConnection.Close();
    return $clientInfoFromDb;
}

function Invoke-BoardwalkSmokeTestForSingleUrl
{
	Param
    (
        [string]$testUrl
    )
    
    $testResult ="unknown";
    try {
        $bwPing = Invoke-RestMethod -Method Get -Uri $testUrl;

        if($bwPing.SelectNodes("html/body/h1").InnerText -ne "BoardwalkTech Inc.") {
            $testResult = "failed";
        }
        else {
            $testResult = "passed";
        }
    }
    catch {
        $testResult = "failed-critical";
    }
    return $testResult;
}

# Parameter Arg: for local debugging 
    # [string[]] $ClientIds = @("1083");
    # [string] $StageName = "STG-EUW";
    # [string] $TagName = "ROLE_PURPOSE";

[string]$env = $StageName;

Write-Host " ";
Write-Host "Retreiving Resource Information needed for $env ...";
Write-Host " ";

# import modules
Import-Module -Name $PSScriptRoot\..\DevOps -Force;
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force;

# Get Core Subscription Name for the targeted environment
$gatewaySubName = Get-GatewaySubscriptionFromStageName -StageName $env;

# Switch to the core subscription to get App Gateway
$gatewaySubscription = Set-AzContext $gatewaySubName;

$kv = Get-KeyVaultNameFromStageName -StageName $env;
$KvObj = Get-AzKeyVault -VaultName $kv

$ResourceGroup = $KvObj.ResourceGroupName;
$connString = (Get-AzKeyVaultSecret -VaultName $kv -Name 'connectionstring-clientdb').SecretValueText;

Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

$azResourceType = "Microsoft.Web/sites";
$tagValueName = "App Service for Boardwalk Client {0}"
$poolName = "pool{0}";
$certName = "*MySslCert{0}*";
$listenerName = "*{0}Listener";
$fqdn = "{0}.azurewebsites.net";
$ruleSetName = "Ruleclient-{0}";
$lockedDownSmokeTestUrlTemplate = "https://{0}/html/PingBWServer.html";

#Get Boardwalk URL pattern for the targeted environment
$hostName = Get-BoardwalkMainHostPatternFromStageName -StageName $env;

Write-Host "Getting all BW App Gateways in $env ...";
$appGatewayList = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup; 

foreach($client in $ClientIds)
{
    try{
        $clientInfo = Get-ClientSubInfo $client -as [int] $connString;
        $TenantSubsriptionName = $clientInfo."TenantSubscriptionName";
        $TenantResourceGroupName = $clientInfo."TenantResourceGroupName";
        $routingAppServiceName = $clientInfo."AppService".ToUpper();

        # Switch to the tenant subsription to find client app service
        $empty = Set-AzContext $TenantSubsriptionName;

        $tagValue =  $tagValueName -f $client;
        $client = $client.PadLeft(5, '0');
        
        Write-Host "----------------------";
        Write-Host "Verify client: $client";
        Write-Host "    Verify App Service ... " -NoNewline;
        $appService = Get-AzResource -ResourceType $azResourceType -TagName $TagName -TagValue $tagValue -ResourceGroupName $TenantResourceGroupName;
        
        $warningMess = $null;
        $isMultAppServiceExist = $false;
        if($null -eq $appService) {
            Write-Host -ForegroundColor Red "Failed";
            Write-Host -ForegroundColor Yellow "        App service doesn't exist, could be due to wrong sub ($TenantSubsriptionName), App Service was tagged incorrectly, or wasn't provisioned";            
            $routingappService = Get-AzResource -Name $routingAppServiceName -ResourceGroupName $TenantResourceGroupName;
            $tagValue = $routingappService.Tags["$($TagName)"]
            $warningMess = "        Warning: Routing table has resource of $routingAppServiceName, its $TagName has a value of '$tagValue'";
            Write-Host -ForegroundColor Yellow $warningMess;
        } else {
            # If there are more than one app service for a client get the latest one
            if ($appService -is [system.array] -and $appService.Length -gt 0 ) 
            {
                $isMultAppServiceExist = $true;
                $warningMess = "      Warning: $($appService.Length) apps have the same $TagName tag value, app listed above is latest.";
                $appService = $appService[$appService.Length - 1];
            }
            
            Write-Host -ForegroundColor Green "Success. App: $($appService.Name) ... SubId: $($clientInfo.AzureSubscriptionID)";
            if($isMultAppServiceExist){
                Write-Host -ForegroundColor Yellow $warningMess;

                if ($appService.Name -ne $clientInfo."AppService"){
                    $warningMess = "      Warning: Found resource mismatch between found app service '$($appService.Name)' and app service in routing table '$($routingAppServiceName)'";
                    Write-Host -ForegroundColor Yellow $warningMess;
                }
            }
        }

        #Verify all WAF items
        $isValidWaf = $true;
        #Verify Listener
        #Write-Host "    Verifying listener for clientId: $client ... " -NoNewline;
        foreach ($appGatewayItem in $appGatewayList)
        {
            $listener = Get-AzApplicationGatewayHttpListener -ApplicationGateway $appGatewayItem | Where-Object Name -Like ($listenerName -f $client);
            $backendPool = Get-AzApplicationGatewayBackendAddressPool -ApplicationGateway $appGatewayItem | Where-Object Name -eq ($poolName -f $client);
            $ruleSet = Get-AzApplicationGatewayRequestRoutingRule -ApplicationGateway $appGatewayItem | Where-Object Name -eq ($ruleSetName -f $client);
            if (($null -ne $listener) -or ($null -ne $backendPool) -or ($null -ne $ruleSet)) {
                Write-Host -ForegroundColor Green "    At least one WAF item found in gateway $($appGatewayItem.Name)";
                $appGateway = $appGatewayItem;
                break;
            }            
        }

        # Verify Backend pool
        if ($null -ne $appGateway)
        {
            $backendPool = Get-AzApplicationGatewayBackendAddressPool -ApplicationGateway $appGateway | Where-Object Name -eq ($poolName -f $client);
        }
        #Write-Host "    Verifying Backend pool for clientId: $client ... " -NoNewline;
        if($null -eq $backendPool){   
            Write-Host "    Verifying Backend pool for clientId: $client ... " -NoNewline;
            Write-Host -ForegroundColor Red "Failed.";
            $isValidWaf = $false;
        } else {
            #Write-Host "    Verifying Backend pool for clientId: $client ... " -NoNewline;
            #Write-Host -ForegroundColor Green "Success";

            # Verify Backend pool Fqdn
            #Write-Host "    Verifying Backend pool Fqdn for clientId: $client ... " -NoNewline;
            if($null -eq $backendPool.BackendAddresses -or `
                $backendPool.BackendAddresses.Length -eq 0 -or `
                [string]::IsNullOrEmpty($backendPool.BackendAddresses[0].Fqdn) -or `
                $backendPool.BackendAddresses[0].Fqdn -ne ($fqdn -f $appService.Name)){

                    Write-Host "    Verifying Backend pool Fqdn for clientId: $client ... " -NoNewline;
                    Write-Host -ForegroundColor Red "Failed.";            
                    $isValidWaf = $false;
                } else {
                #Write-Host "    Verifying Backend pool Fqdn for clientId: $client ... " -NoNewline;
                #Write-Host -ForegroundColor Green "Success";
            }
        }         

        # Verify Ruleset
        if ($null -ne $appGateway)
        {
            $ruleSet = Get-AzApplicationGatewayRequestRoutingRule -ApplicationGateway $appGateway | Where-Object Name -eq ($ruleSetName -f $client);
        }
        #Write-Host "    Verifying Rule set for clientId: $client ... " -NoNewline;
        if($null -eq $ruleSet -or `
            $ruleSet.BackendAddressPoolText -notlike "*$($poolName -f $client)*" -or `
            $ruleSet.HttpListenerText -notlike "*$($listenerName -f $client)*") {
                Write-Host "    Verifying Rule set for clientId: $client ... " -NoNewline;
                Write-Host -ForegroundColor Red "Failed.";
                $isValidWaf = $false;
            } else {
            #Write-Host "    Verifying Rule set for clientId: $client ... " -NoNewline;
            #Write-Host -ForegroundColor Green "Success";
        }

        if($null -eq $listener) {
            Write-Host "    Verifying listener for clientId: $client ... " -NoNewline;
            Write-Host -ForegroundColor Red "Failed";
            $isValidWaf = $false;
        } else {
            #Write-Host "    Verifying listener for clientId: $client ... " -NoNewline;
            #Write-Host -ForegroundColor Green "Success";

            # Verify Ssl Cert
            #Write-Host "    Verifying SslCertificate for clientId: $client ... " -NoNewline;
            if([string]::IsNullOrEmpty($listener.SslCertificateText) -or $listener.SslCertificateText -notlike ($certName -f $client)){
                Write-Host "    Verifying SslCertificate for clientId: $client ... " -NoNewline;
                Write-Host -ForegroundColor Red "Failed";
                $isValidWaf = $false;
            } else {
                #Write-Host "    Verifying SslCertificate for clientId: $client ... " -NoNewline;
                #Write-Host -ForegroundColor Green "Success";
            }
        
            # Verify Hostname
            #Write-Host "    Verifying listener hostname for clientId: $client ... " -NoNewline;
            if([string]::IsNullOrEmpty($listener.HostName) -or $listener.HostName -notlike ($hostName -f $client)){
                Write-Host "    Verifying listener hostname for clientId: $client ... " -NoNewline;
                Write-Host -ForegroundColor Red "Failed";
                $isValidWaf = $false;
            } else {
                #check for listener hostname & client Resource URL mismatch
                if ($listener.HostName -ne $clientInfo.ResourceUrl)
                {
                    Write-Host -ForegroundColor Red "    Found listener hostname mismatch '$($listener.HostName)' vs. client Resource URL '$($clientInfo.ResourceUrl)' ... Failed";
                    $isValidWaf = $false;
                }
                #Write-Host "    Verifying listener hostname for clientId: $client ... " -NoNewline;
                #Write-Host -ForegroundColor Green "Success";
            }
        }

        if ($true -eq $isValidWaf) {     
            Write-Host -ForegroundColor Green "    All WAF items verified ... Success";
            
            #verify app service has BW deployed
            $foundAppServiceName = $appService.Name;
            $mappedUrl = $hostName -f $client;
            Write-Host "    Now checking if BW has been deployed to $foundAppServiceName..." -NoNewline;
            $appServiceUrl = "https://{0}.azurewebsites.net/html/PingBWServer.html" -f $foundAppServiceName;

            $resourceUrl = $clientInfo.ResourceUrl;
            $lockedDownUrl = $lockedDownSmokeTestUrlTemplate -f $resourceUrl;
            
            $testResultOpenUrl = Invoke-BoardwalkSmokeTestForSingleUrl -testUrl $appServiceUrl;
            $testResultLockedUrl = $null;
            if ($testResultOpenUrl -eq "failed-critical")
            {
                $testResultLockedUrl = Invoke-BoardwalkSmokeTestForSingleUrl -testUrl $lockedDownUrl;
            }

            switch ($testResultOpenUrl) {
                "passed" 
                {  
                    Write-Host -ForegroundColor Green "Success";
                }
                "failed" 
                {
                    $isValidWaf = $false;
                    Write-Host -ForegroundColor Red "failed";
                    Write-Host -ForegroundColor Yellow "Please redeploy BW to $foundAppServiceName";                    
                }
                "failed-critical" 
                {
                    $isValidWaf = $false;

                    #failed-critical error may be occurring beacuse app service is already locked down
                    if ($testResultLockedUrl -eq "passed")
                    {
                        Write-Host -ForegroundColor Red "failed";
                        Write-Host -ForegroundColor Yellow "    App service $foundAppServiceName is already locked down!!!";
    
                    }
                    else {
                        Write-Host -ForegroundColor Red "failed";
                        Write-Host -ForegroundColor Yellow "    OpenUrl Smoke test '$testResultOpenUrl', Locked Smoke test '$testResultLockedUrl'; need to investigate further";                         
                    }
                }
                Default 
                {
                    $isValidWaf = $false;
                    Write-Host -ForegroundColor Red "failed for unknown reason on smoke test";
                    Write-Host -ForegroundColor Yellow "    Please investigate further";
                }
            }
            
            # try {
            #     $bwPing = Invoke-RestMethod -Method Get -Uri $appServiceUrl;
        
            #     if($bwPing.SelectNodes("html/body/h1").InnerText -ne "BoardwalkTech Inc.") {
            #         $isValidWaf = $false;
            #         Write-Host -ForegroundColor Red "failed";
            #         Write-Host -ForegroundColor Yellow "Please redeploy BW to $foundAppServiceName";
            #     }
            #     else {
            #         Write-Host -ForegroundColor Green "Success";
            #     }
            # }
            # catch {
            #     $isValidWaf = $false;
            #     Write-Host -ForegroundColor Red "failed";
            #     Write-Host -ForegroundColor Yellow "    Check if app service is already locked down.  If not locked down, please redeploy BW to $foundAppServiceName";
            # }
                
 

        } else {
            Write-Host -ForegroundColor Red "    All WAF items NOT verified ... Failed";
        }

        if ($true -eq $isValidWaf){

            #confirm whether app service should be locked down
            $inputAnswer =  Read-Host -Prompt "Validation passed, do you want to lockdown the app service(yes, no)?";
            if ($inputAnswer -ne 'yes')
            {
                Write-Host -ForegroundColor Yellow "    Bypassed app service lockdown step for this client";
                continue;
            }

            $spnObj = Get-SpnInfoFromStageName -StageName $env;
            $ClientSecret = $spnObj.SpnPassword;

            $wafTenantId = $clientInfo."TenantId";
            $wafSpnId = $clientInfo."SpnId";

            Write-Verbose "get auth token";
            $accessTokenHeader = Get-AzureAdminHeader -TenantId $wafTenantId -ClientId $wafSpnId -ClientSecret $ClientSecret;
            $azBaseUri = "https://management.azure.com";
            $azApiVersion = "2018-02-01";
            $azResourceType = "Microsoft.Web/sites";

            #            Write-Host -ForegroundColor Green "Success. App: $($appService.Name) ... SubId: $($clientInfo.AzureSubscriptionID)";
            $foundAppServiceName = $appService.Name;
            try 
            {        
                Write-Host "Adding Policy restriction... " -NoNewline;
                $azResourceId = "/subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}" -f $clientInfo.AzureSubscriptionID, $TenantResourceGroupName, $azResourceType, $foundAppServiceName;
                $azAdminBearerTokenEndpoint = "/config/web";
                $adminBearerTokenUri = "{0}{1}{2}?api-version={3}" -f $azBaseUri, $azResourceId, $azAdminBearerTokenEndpoint, $azApiVersion;

                #Get subnet resourceid from BW gateway
                $gwIPConfig = $appGateway.GatewayIPConfigurations[0];
                $gwSubnet = $gwIPConfig.Subnet;
                $VnetSubnetResourceId = $gwSubnet.Id;
                
                $parmObject = @{
                    properties = @{ ipSecurityRestrictions =
                    @(
                        @{
                            ipAddress = $null
                            name = $PolicyName
                            tag = "Default"
                            description = $null
                            action = "Allow"
                            priority = $Priority
                            vnetSubnetResourceId = $VnetSubnetResourceId
                        }
                    )}
                };
                $jsonObject = ConvertTo-Json -Depth 4 $parmObject;
                
                $adminBearerToken = Invoke-RestMethod -Method Put -Uri $adminBearerTokenUri -ContentType "application/json" -Body $jsonObject -Headers $accessTokenHeader;
                Write-Host -ForegroundColor Green "    Success";
            }
            catch 
            {
                Write-Host -ForegroundColor Yellow "$_";
                continue;
            }

        }
        
    }
    catch {
        Write-Host -ForegroundColor Yellow "$_";
        continue;
    }
}

