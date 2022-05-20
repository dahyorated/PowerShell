<#
.SYNOPSIS
Clones Tenant Azure KeyVault Secrets from Source to Target KeyVault.

.DESCRIPTION
This clones all tenant Azure KeyVaults Secrets from source to target KeyVault.  The following actions are taken...
    1) csv containing list of valid tenantIds is read in.
    2) csv containing list of valid secret mapping values are read in.  For each mapping item, a mapping Id and mapping mask values are included.
    3) script lists all tenandIds, list of sample secrets to be matched for each tenant and a total of how many secrets will be processed.
    4) prompt is deisplayed to allow the user to abort if the sample information does not look right.
    5) If continuing, each valid item is either inserted or updated.  Only existing secrets with different values will be updated.
    6) Action on each item is logged until the script completes.

.EXAMPLE
CopyTenantKeyValues_BetweenKeyVaults    -CsvFile_TenantIds @("C:\csvTest\TestDr\TenantIds_GhtestDev.csv")
                                        -CsvFile_KvTenantTemplateNames @("C:\csvTest\TestDr\TenantTemplateNames_GhtestDev.csv")
                                        -Source_KeyVaultName "EUWDGTP005AKV01"
                                        -Destination_KeyVaultName "USEDGTP004AKV01"


.PARAMETER CsvFile_TenantIds
This is the csv that contains the list of valid tenantIDs, The columns are as follows...
    1) "TenantId" - integer values
    2) "OptionalNote" - free form text field for notes.

.PARAMETER CsvFile_KvTenantTemplateNames
This is the csv that contains the list of valid tenant template names for their KeyValue secrets.  The columns are as follows...
    1) "SrcKeyTemplateName" - contains template value, example: segA[id]segB is template for secret name where [id] is replaced by tenants' actual Id.
    2) "MapField" - contains string in SrcKeyTemplateName that is replaced by tenants' actual id.
    3) "MapMask" - determines masking format for tenants id.  "5digit" masks to a 5-digit number; "4digit" masks to 4-digit number
    4) "OptionalNote" - free form test field for notes.

.PARAMETER Source_KeyVaultName
Resource name of Source KeyVault.

.PARAMETER Destination_KeyVaultName
Resource name of Destination KeyVault

#>

#
# CopyTenantKeyValues_BetweenKeyVaults.ps1
#
# Dev Environment
#   Source: EUWDGTP005AKV01
#     Dest: USEDGTP004AKV01
#
# Stage Environment
#   Source: EUWXGTP020AKV01
#     Dest: USEXGTP021AKV01
# 
# Connect-AzAccount -UseDeviceAuthentication
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [string]$CsvFile_TenantIds = "C:\csvTest\TestDr\TenantIds_GhtestDev.csv",
    [Parameter(Mandatory=$False)]
    [string]$CsvFile_KvTenantTemplateNames = "C:\csvTest\TestDr\TenantTemplateNames_GhtestDev.csv",
    [Parameter(Mandatory=$False)]
	[string]$Source_KeyVaultName = "EUWDGTP005AKV01",
	[Parameter(Mandatory=$False)]
	[string]$Destination_KeyVaultName = "USEDGTP004AKV01"
)

# Functions
function BuildTenantKey {
    param (
        [System.Object]$keyObject,
        [int]$tenantId
    )
    
    $wrkFromName = $keyObject.("SrcKeyTemplateName");
    $wrkMapField = $keyObject.("MapField");
    $wrkMapMask = $keyObject.("MapMask");

    # map in tenant id 
    $wrkSampleKey = $wrkFromName;
    if ("5digit" -eq $wrkMapMask)
    {
        $wrkSampleKey = $wrkSampleKey.Replace($wrkMapField, $tenantId.ToString().PadLeft(5, '0'));
    }
    elseif ("4digit" -eq $wrkMapMask) 
    {
        $wrkSampleKey = $wrkSampleKey.Replace($wrkMapField, $tenantId.ToString().PadLeft(4,'0'));
    }
    else 
    {
        $wrkSampleKey = $wrkSampleKey.Replace($wrkMapField, "[nomap]");
    }

    return $wrkSampleKey;    
}

function KeyValuesAreSame{
    param (
        [System.Object]$srcObj,
        [System.Object]$dstObj
    )    

    if ($null -eq $dstObj){
        return $false;
    }

    if ($srcObj.SecretValueText -eq $dstObj.SecretValueText){
        return $true;
    }

    return $false;
}


# Main Logic
$destStringItems = $null;
$tenantIds = Import-Csv $CsvFile_TenantIds;
$tenantKeyNames = import-csv $CsvFile_KvTenantTemplateNames;

#List Clients that will be processed
Write-Host "Cloning for the following TenantIds from $Source_KeyVaultName to $Destination_KeyVaultName";
foreach ($tenantId in $tenantIds)
{
    $wrkTenantId = $tenantId.("TenantId");
    $wrkNote = $tenantId.("OptionalNote");
    Write-Host "TenantId to be processed: '$wrkTenantId'";        
}

#List Template Values that will be processed
Write-Host "Cloning the following Tenant keyNames from $Source_KeyVaultName to $Destination_KeyVaultName";
foreach ($keyName in $tenantKeyNames)
{
    $sampleId = 123;
    $wrkFromName = $keyName.("SrcKeyTemplateName");
    $wrkMapMask = $keyName.("MapMask");
    $wrkSampleKey = BuildTenantKey $keyName $sampleId;
 
    Write-Host "Sample Vault Key Added to List: '$wrkFromName' maps to '$wrkSampleKey' for sample Id '$sampleId' using '$wrkMapMask'  mapping.";
}

#Confirm You want to proceed
Write-Host "";
$wrkCount = $tenantIds.Count * $tenantKeyNames.Count;
$inputAnswer =  Read-Host -Prompt "You will be processing $wrkCount tenant keys, Continue with cloning them (yes, no)?";

if ($inputAnswer -ne 'yes')
{
    Write-Host "Script aborted per user response";
    exit;
}

#Process each item for each tenant found in spreadsheets
foreach ($tenantId in $tenantIds)
{
    foreach ($keyName in $tenantKeyNames)
    {
        $sourceObj = $null;
        $destObj = $null;

        #build KV keyName
        $iId = [int]$tenantId.TenantId
        $wrkSrcSecretName = BuildTenantKey $keyName $iId ;
        $wrkDestSecretName = $wrkSrcSecretName;

        if (-not [string]::IsNullOrWhiteSpace($wrkSrcSecretName))
        {
            # get source information
            
            $sourceObj = Get-AzKeyVaultSecret -VaultName $Source_KeyVaultName -Name $wrkSrcSecretName -ErrorAction Stop;
            
            if ($null -eq $sourceObj)
            {
                Write-Host  "**** $wrkSrcSecretName not cloned: Does not exist in source Key Vault ****";    
                continue;
            }
            
            # get destination information; don't upsert if the same
            $destObj = Get-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName;
            $isExist = KeyValuesAreSame $sourceObj $destObj;
            if ($true -eq $isExist)
            {
                Write-Host  "**** $wrkSrcSecretName not cloned: Key values are same ****";
                continue;
            }
       
            Set-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName -SecretValue $sourceObj.SecretValue;

            if ($null -eq $destObj){
                Write-Host "Successfully cloned(insert) '$wrkSrcSecretName' to '$wrkDestSecretName'";
            }
            else {
                Write-Host "Successfully cloned(update) '$wrkSrcSecretName' to '$wrkDestSecretName'";                
            }
        }
    }
}

Write-Host "done";
