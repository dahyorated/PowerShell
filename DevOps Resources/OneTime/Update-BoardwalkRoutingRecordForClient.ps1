<#
.SYNOPSIS
Updates Service column in ClientServiceConfiguration row from "bwapods" to "boardwalk" for a specific client 

.DESCRIPTION
This script finds and updates the Service column in a ClientConfiguration row from "bwapods" to "boardwalk" for a specific client.  The following actions are taken...
    1) User enters clientId they are working with.
    2) Retreives clientdb connection string from targetId keyvault (parameter).
    3) Builds out select command from template, retrieves all candidates rows and displays them
    4) User enter rowId to update ...this rowId is validated ... script aborts if invalid.
    5) SQL Update statement is display and is executed is user chooses to continue. 

.EXAMPLE
Update-BoardwalkRoutingRecordForClient -keyvault "EUWDGTP005AKV01"

#>
#
# Dev Environment
#   kv: EUWDGTP005AKV01
#
# Stage Environment
#   kv: EUWXGTP020AKV01
#
# Prod Environment
#   kv: EUWPGTP018AKV04
# 
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
	[string]$keyvault = "EUWDGTP005AKV01zzz"
)

# Functions
# none

$connClientDb = 'connectionstring-clientdb';

#template of select statement
$tmpSelectClientConfig = "select cc.ClientId";
$tmpSelectClientConfig += " ,csc.ClientServiceConfigurationId";
$tmpSelectClientConfig += " ,csc.Service";
$tmpSelectClientConfig += " ,csc.ResourceTypeId";
$tmpSelectClientConfig += " ,csc.AccountName";
$tmpSelectClientConfig += " ,csc.ResourceURL";
$tmpSelectClientConfig += " ,csc.ErrorMessage";
$tmpSelectClientConfig += " FROM Common.ClientServiceConfiguration csc";
$tmpSelectClientConfig += " INNER JOIN Common.ClientConfiguration cc ON cc.ClientConfigId = csc.ClientConfigId";
$tmpSelectClientConfig += " WHERE (cc.ClientId = %%clientId%%)";
$tmpSelectClientConfig += " AND (csc.Service LIKE 'bwa%')";
$tmpSelectClientConfig += " AND (csc.ResourceTypeId = 3)";
$tmpSelectClientConfig += " ORDER BY csc.ClientConfigId desc, csc.ClientServiceConfigurationId;"

#template of update statement
$tmpUpdateClientConfig = "UPDATE Common.ClientServiceConfiguration";
$tmpUpdateClientConfig += " SET Service = 'boardwalk'";
#$tmpUpdateClientConfig += " SET ErrorMessage = 'boardwalk error3'";
$tmpUpdateClientConfig += " WHERE ClientServiceConfigurationId = %%configId%%";

#template of select confirmation statement
$tmpSelectConfirmConfig = "select cc.ClientId";
$tmpSelectConfirmConfig += " ,csc.ClientServiceConfigurationId";
$tmpSelectConfirmConfig += " ,csc.Service";
$tmpSelectConfirmConfig += " ,csc.ResourceTypeId";
$tmpSelectConfirmConfig += " ,csc.AccountName";
$tmpSelectConfirmConfig += " ,csc.ResourceURL";
$tmpSelectConfirmConfig += " ,csc.ErrorMessage";
$tmpSelectConfirmConfig += " FROM Common.ClientServiceConfiguration csc";
$tmpSelectConfirmConfig += " INNER JOIN Common.ClientConfiguration cc ON cc.ClientConfigId = csc.ClientConfigId";
$tmpSelectConfirmConfig += " WHERE ClientServiceConfigurationId = %%configId%%";

#Enter ClientId & buildout select statement
Write-Host "";
$wrkCount = $keyNames.Count;
$inClientId =  Read-Host -Prompt "Enter ClientId ";
if ($inClientId -eq '')
{
    Write-Host "Script aborted per user response";
    exit;
}
$selectClientConfig = $tmpSelectClientConfig -replace "%%clientId%%", $inClientId;
#Write-Host $selectClientConfig;

#Getting clientdb connection string from  keyvault
$clientDbConnSecret = Get-AzKeyVaultSecret -VaultName $keyvault -Name $connClientDb  ;  
$clientDbConnString = $clientDbConnSecret.SecretValueText  ; 
#Write-Host $clientDbConnString;

# open a sql connection, execute select statement 
$conn = new-object System.Data.SqlClient.SQLConnection($clientDbConnString) ; 
$conn.Open(); 
$cmd = new-object System.Data.SqlClient.SqlCommand($selectClientConfig, $conn) ;
$rdr = $cmd.ExecuteReader();
$DataTable = New-Object system.data.datatable;
$DataTable.load($rdr);
Write-Host "";
Write-Host "*** List of config eligible to flip from bwapods to boardwalk ***";
$DataTable | Out-Default; 

#Enter ClientServiceConfigurationId
Write-Host "";
$wrkCount = $keyNames.Count;
$inConfigId =  Read-Host -Prompt "Enter ClientServiceConfigurationId to flip ";
if ($inConfigId -eq '')
{
    Write-Host "Script aborted per user response";
    exit;
}

#confirm id entered is value 
$match = 'n';
$cmd.CommandText = $selectClientConfig;
$rdr = $cmd.ExecuteReader();
while ($rdr.Read()) {
    if ($rdr["ClientServiceConfigurationId"] -eq ($inConfigId -as [int])) {
        $match = 'y';
    }
}
if ($match -eq 'n')
{
    Write-Host "Script aborted, invalid ClientServiceConfigurationId entered.";
    exit;
}

$rdr.Close();

#display derived update statment
$updateClientConfig = $tmpUpdateClientConfig -replace "%%configId%%", $inConfigId;
Write-Host "";
Write-Host "*** Preview of Update statement ***";
Write-Host $updateClientConfig;
Write-Host "";

#confirm whether statement should be updated
$inputAnswer =  Read-Host -Prompt "Process this SQL Update Statement(yes, no)?";
if ($inputAnswer -ne 'yes')
{
    Write-Host "Script aborted per user response";
    exit;
}

$cmd.CommandText = $updateClientConfig;
$cmd.ExecuteNonQuery();

Write-Host "";
# open a sql connection, execute select statement
$selectConfirmConfig = $tmpSelectConfirmConfig -replace "%%configId%%", $inConfigId;
$cmd.CommandText = $selectClientConfig;
$rdr = $cmd.ExecuteReader();
$DataTableUpdated = New-Object system.data.datatable;
$DataTableUpdated.load($rdr);
Write-Host "";
Write-Host "*** Config Row Updated as follows ***";
$DataTableUpdated | Out-Default; 

Write-Host "done";
