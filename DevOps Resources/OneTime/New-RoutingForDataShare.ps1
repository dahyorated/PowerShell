<#
.SYNOPSIS
This script is to insert routing records for ADS for clients done manually or semi-manually

.DESCRIPTION
insert client routing for azure data share based on the storage containers provisioned for the client and region    

.PARAMETER clientId
GTP Client ID (integer)

.PARAMETER Account
Azure Data Share Account Name

.PARAMETER kv
Azure KeyVault containing the clientdb connection string

.PARAMETER regionCD
The Azure Region Code for the Data Share Account

.Example 
.\New-RoutingForDataShare.ps1 -clientid 4 -account "euwdgtp005cdb02" -kv "EUWDGTP005AKV01" -regionCd "westeurope" 
#>

[CmdletBinding()]
param(
    [int] $clientid,
    [string]  $account,
    [string] $kv,
    [string] $regionCd
)

$sql = "DECLARE @clientId BIGINT = $clientId
DECLARE @account NVARCHAR(100) = '$account'
DECLARE @regionCd nvarchar(100) = '$regionCd'

INSERT INTO [Common].[ClientServiceConfiguration] ([ClientConfigId],[Service],[ResourceTypeId],[AccountName],[Container],[IsProvisioned],[IsRequired],[IsFailed]
           ,[ErrorCd],[GTPRecordStatusId],[IsDeleted],[CreatedUser],[CreatedDtm],[UpdatedUser],[UpdatedDtm])
     SELECT cc.ClientConfigId,csc.[Service],8,@account,csc.Container,1,1,0,0,1,0,'script',GETUTCDATE(),'script',GETUTCDATE()
FROM Common.ClientConfiguration cc
INNER JOIN Common.ClientServiceConfiguration csc ON cc.ClientConfigId = csc.ClientConfigId
INNER JOIN common.AzureRegion ar ON cc.AzureRegionId = ar.AzureRegionId
WHERE cc.ClientId = @clientId
AND csc.ResourceTypeId = 1
AND ar.AzureRegionCd = '$regionCd'"

Write-Output $SQL


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


