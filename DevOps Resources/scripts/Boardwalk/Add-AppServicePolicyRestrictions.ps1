<#
.SYNOPSIS
Add WAF Restriction to an app service

.DESCRIPTION
Add WAF restriction to an app service. Additionally it will verify 1) if the App Service exists 2) BW was successfully deployed.

.PARAMETER AppServices
An array of app service names to process

.PARAMETER ResourceGroup
The resource group where the list of app services reside

.PARAMETER VnetSubnetResourceId
Full Azure resource ID of the Subnet where the WAF resides

.PARAMETER PolicyName
The name of the Policy restriction to be created

.PARAMETER Priority
This switch skips the creation of the app service plan, but still creates the app service using the content of the -AppSvcPlanFullPathname JSON file.

.PARAMETER ClientId
SPN client ID used to connect to the Azure Rest API

.PARAMETER ClientSecret
SPN client secret used to connect to the Azure Rest API

.PARAMETER TenantId
Azure Tenant Id

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ClientId = "",
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret = "",
    [Parameter(Mandatory=$true)]
    [string]$TenantId = "",
    [Parameter(Mandatory=$true)]
    [string[]]$AppServices = @(),
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId = "",
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "GT-WEU-GTP-TENANT-PROD-RSG",
    [Parameter(Mandatory=$false)]
    [string]$VnetSubnetResourceId = "/subscriptions/e45bb7e2-b46d-4f73-b12f-66c7ed1c97b7/resourceGroups/gt-weu-gtp-core-prod-rsg/providers/Microsoft.Network/virtualNetworks/EUWPGTP018VNT01/subnets/EUWPGTP018SBN05",
    [string]$PolicyName = "WAF RESTRICTION",
    [int]$Priority = 100
    
)


Import-Module -Name $PSScriptRoot\..\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

Write-Verbose "get auth token";
$accessTokenHeader = Get-AzureAdminHeader -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret;
$azBaseUri = "https://management.azure.com";
$azApiVersion = "2018-02-01";
$azResourceType = "Microsoft.Web/sites";


foreach($appService in $AppServices)
{
    try {
        $subScription = Set-AzContext $SubscriptionId;
        
        # Verify app service exists
        Write-Host "Checking if $appService exists... " -NoNewline;
        $verifyAppService = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $appService -ErrorAction Ignore;

        if($null -eq $verifyAppService){
            Write-Host -ForegroundColor Red "failed";
            Continue;
        }
        Write-Host -ForegroundColor Green "Success";

        #verify app service has BW deployed
        Write-Host "Checking if BW has been deployed to $appService..." -NoNewline;
        $appServiceUrl = "https://{0}.azurewebsites.net/html/PingBWServer.html" -f $appService;

        try {
            $bwPing = Invoke-RestMethod -Method Get -Uri $appServiceUrl;

            if($bwPing.SelectNodes("html/body/h1").InnerText -ne "BoardwalkTech Inc.") {
                Write-Host -ForegroundColor Red "failed";
                Write-Host -ForegroundColor Yellow "Please redeploy BW to $appService";
                Continue;
            }
        }
        catch {
            Write-Host -ForegroundColor Red "failed";
            Write-Host -ForegroundColor Yellow "Please redeploy BW to $appService";
            Continue;
        }
        
        Write-Host -ForegroundColor Green "Success";

        Write-Host "Adding Policy restriction... " -NoNewline;
        $azResourceId = "/subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}" -f $SubscriptionId, $ResourceGroup, $azResourceType, $appService;
        $azAdminBearerTokenEndpoint = "/config/web";
        $adminBearerTokenUri = "{0}{1}{2}?api-version={3}" -f $azBaseUri, $azResourceId, $azAdminBearerTokenEndpoint, $azApiVersion;
        
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
        Write-Host -ForegroundColor Green "Success";
    }
    catch {
        Write-Host -ForegroundColor Yellow "$_";
        continue;
    }
}

