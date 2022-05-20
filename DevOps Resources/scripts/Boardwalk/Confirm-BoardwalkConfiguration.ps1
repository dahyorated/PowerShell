<#
.SYNOPSIS
Verify a number of configurations for a Boardwalk client request

.DESCRIPTION
Script to verify app service, App Gateway Listener, Backend pool and Ruleset for a given set of clients.
Note: This script is intended to run in a console manually and not through a pipeline

.PARAMETER ClientIds
Array of client ids to confirm Boardwalk configuration

.PARAMETER ResourceGroup
Tenant resource group name

.PARAMETER TagName
Name of the tag to find an app service

.Example
.\Confirm-BoardWalkConfiguration.ps1 -ClientIds @("1273", "1284") -StageName "PRD-EUW"

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
    $sql = "SELECT ClientServiceConfigurationId, IsProvisioned from Common.ClientServiceConfiguration";
    $sql = "select cs.ClientId, s.* from Common.Subscription s ";
    $sql = $sql + "inner join Common.ClientSubscription cs ON s.SubscriptionId = cs.SubscriptionId ";
    $sql = $sql + "where cs.ClientId = " + $clientId.ToString();
	$cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
    $rdrResults = $cmd.ExecuteReader(); 
    $exists = $rdrResults.Read();
    $value1 = $rdrResults["ClientId"];	
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "ClientId" -Value $rdrResults["ClientId"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "TenantSubscriptionName" -Value $rdrResults["SubscriptionName"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "AzureSubscriptionID" -Value $rdrResults["AzureSubscriptionID"];
    $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "TenantResourceGroupName" -Value $rdrResults["TenantPrimaryResourceGroupName"];
    $rdrResults.Close();
    $sqlConnection.Close();
    return $clientInfoFromDb;
}

# Parameter Arg: for local debugging 
#[string[]] $ClientIds = @("1610");
#[string] $StageName = "PRD-EUW";
#[string] $TagName = "ROLE_PURPOSE";

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
$empty = Set-AzContext $gatewaySubName;

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
        
        # Switch to the tenant subsription to find client app service
        $empty = Set-AzContext $TenantSubsriptionName;

        $tagValue =  $tagValueName -f $client;
        $client = $client.PadLeft(5, '0');
        
        Write-Host "Verify client: $client";
        Write-Host "    Verify App Service ... " -NoNewline;
        $appService = Get-AzResource -ResourceType $azResourceType -TagName $TagName -TagValue $tagValue -ResourceGroupName $TenantResourceGroupName;
        
        if($null -eq $appService) {
            Write-Host -ForegroundColor Red "Failed";
            Write-Host -ForegroundColor Yellow "    App service doesn't exist, this could be due to wrong subscription ($TenantSubsriptionName), App Servivce was tagged incorrectly, or it wasn't provisioned";            
        } else {
            # If there are more than one app service for a client get the latest one
            if ($appService -is [system.array] -and $appService.Length -gt 0 ) {
                $appService = $appService[$appService.Length - 1];
            }
            
            Write-Host -ForegroundColor Green "Success. App: $($appService.Name) ... SubId: $($clientInfo.AzureSubscriptionID)";
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
                #Write-Host "    Verifying listener hostname for clientId: $client ... " -NoNewline;
                #Write-Host -ForegroundColor Green "Success";
            }
        }
                
        # Verify Backend pool
        $backendPool = Get-AzApplicationGatewayBackendAddressPool -ApplicationGateway $appGateway | Where-Object Name -eq ($poolName -f $client);
        #Write-Host "    Verifying Backend pool for clientId: $client ... " -NoNewline;
        if($null -eq $backendPool){   
            Write-Host "    Verifying Backend pool for clientId: $client ... " -NoNewline;
            Write-Host -ForegroundColor Red "Failed.";
            $isValidWaf = $false;
            Continue;
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
        $ruleSet = Get-AzApplicationGatewayRequestRoutingRule -ApplicationGateway $appGateway | Where-Object Name -eq ($ruleSetName -f $client);
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

        if ($true -eq $isValidWaf) {
            Write-Host -ForegroundColor Green "    All WAF items verified ... Success";
        } else {
            Write-Host -ForegroundColor Red "    All WAF items NOT verified ... Failed";
        }
        
    }
    catch {
        Write-Host -ForegroundColor Yellow "$_";
        continue;
    }
}

