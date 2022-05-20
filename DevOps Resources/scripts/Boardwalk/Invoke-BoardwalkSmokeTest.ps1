<#
.SYNOPSIS
Script to Run Boardwalk Smoke Test for each client

.DESCRIPTION
Script to Run Boardwalk Smoke Test for each cliente

.PARAMETER StageName
Stage name where Boardwalk smoke tests should run

.Example
.\Invoke-BoardwalkSmokeTest.ps1 -StageName "PRD-EUW"

#>
  [CmdletBinding()]
  param (
      [Parameter(Mandatory=$true)]
      [ValidatePattern('(DEV|QAT|UAT|DMO|PRF|STG|PRD)-(EUW|USE)')]
      [string]$StageName
  )

#functions
function Get-BoardwalkClients
{
	Param
    (
    )

    $clientList = New-Object System.Collections.ArrayList;

	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection;
	$sqlConnection.ConnectionString = $connString;
    $sqlConnection.Open();
    $sql = "SELECT ";
    $sql = $sql + "cc.ClientId ";
    $sql = $sql + ", c.ClientNm ";
    $sql = $sql + ", csc.AccountName as AppService ";
    $sql = $sql + ", csc.ResourceUrl ";
    $sql = $sql + ", csc.[Service] as ServiceType ";
    $sql = $sql + ", csc.[IsProvisioned] ";
    $sql = $sql + ", c.IsDeleted as ClientDeleted ";
    $sql = $sql + ", cc.IsDeleted as ConfigDeleted ";
    $sql = $sql + ", csc.IsDeleted as ServConfigDeleted ";
    $sql = $sql + ", c.clientNm + ' [' + ltrim(str(cc.clientId)) + ']' as FullName ";
    $sql = $sql + ", ar.AzureRegionCd as AzureRegion ";
    $sql = $sql + "FROM Common.ClientConfiguration cc ";
    $sql = $sql + "INNER JOIN Common.ClientServiceConfiguration csc ON csc.ClientConfigId = cc.ClientConfigId ";
    $sql = $sql + "INNER JOIN common.Client c ON c.ClientId = cc.ClientId ";
    $sql = $sql + "INNER JOIN common.AzureRegion ar ON ar.AzureRegionId = cc.AzureRegionId ";
    $sql = $sql + "WHERE ";
    $sql = $sql + "c.IsDeleted = 0 AND cc.IsDeleted = 0 AND csc.IsDeleted = 0 AND csc.IsProvisioned = 1 ";
    $sql = $sql + "AND csc.ResourceTypeId IN (3) ";
    $sql = $sql + "AND csc.Service IN ('boardwalk','bwapods') ";
    $sql = $sql + "order by cc.ClientId ";

    $cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
    $rdrResults = $cmd.ExecuteReader(); 


    if ($rdrResults.HasRows)
    {
       while ($rdrResults.Read())
       {
           $clientInfoFromDb = New-Object System.Object;
           $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "ClientId" -Value $rdrResults["ClientId"];
           $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "ClientNm" -Value $rdrResults["ClientNm"];
           $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "ResourceUrl" -Value $rdrResults["ResourceUrl"];
           $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "AppService" -Value $rdrResults["AppService"];
           $clientInfoFromDb | Add-Member -MemberType NoteProperty -Name "AzureRegion" -Value $rdrResults["AzureRegion"];
           $clientList.Add($clientInfoFromDb) | Out-Null;
       } 
    }
    
    $rdrResults.Close();
    $sqlConnection.Close();
    return $clientList;
}

# Parameter Arg: for local debugging 
#  [string] $StageName = "STG-EUW";

[string]$env = $StageName;

Write-Host " ";
Write-Host "Retrieving list of clients with Boardwalk provisioned in $env ...";
Write-Host " ";

# import modules
Import-Module -Name $PSScriptRoot\..\DevOps -Force;
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force;

# Get Core Subscription Name for the targeted environment
$subName = Get-GatewaySubscriptionFromStageName -StageName $env;

# Switch to the core subscription to get client list
$subscription = Set-AzContext $subName;

$kv = Get-KeyVaultNameFromStageName -StageName $env;
$KvObj = Get-AzKeyVault -VaultName $kv

$connString = (Get-AzKeyVaultSecret -VaultName $kv -Name 'connectionstring-clientdb').SecretValueText;

#Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

$clientIds = Get-BoardwalkClients;
[string[]] $errorClients = $null;

foreach($client in $ClientIds)
{
    try
    {
        #smoke test App Service
        $clientId = $client."ClientId";
        $currAppService = $client."AppService";
        $url = $client."ResourceUrl";
        Write-Host "    Now smoke testing Boardwalk for client $clientId, $currAppService..." -NoNewline;
        $appServiceUrl = "https://{0}/html/PingBWServer.html" -f $url;
                    
        try {
            $bwPing = Invoke-RestMethod -Method Get -Uri $appServiceUrl;
        
            if($bwPing.SelectNodes("html/body/h1").InnerText -ne "BoardwalkTech Inc.") {
                Write-Host -ForegroundColor Red "Failed";
                $sClientId = $clientId.ToString();
                $errorClients = $errorClients + $sClientId;
            }
            else {
                Write-Host -ForegroundColor Green "Success";
            }
        }
        catch {
            Write-Host -ForegroundColor Red "failed (fatal) ... $appServiceUrl";
            $sClientId = $clientId.ToString();
            $errorClients = $errorClients + $sClientId;
        }
    }
    catch {
        Write-Host -ForegroundColor Yellow "$_";
        continue;
    }   
}

$numClients = $errorClients.Length;

#confirm whether you want to pass the clientIds with error through the validation script
Write-Host "   ";
$inputAnswer =  Read-Host -Prompt "We have found $numClients clients that failed, do you want to validate these BW client app services(yes, no)?";
            if ($inputAnswer -eq 'yes')
            {
                .\Invoke-BoardwalkConfigValidationAndLockdown.ps1 -ClientIds $errorClients -StageName $StageName;
            }
            else {
                $exit;
            }
