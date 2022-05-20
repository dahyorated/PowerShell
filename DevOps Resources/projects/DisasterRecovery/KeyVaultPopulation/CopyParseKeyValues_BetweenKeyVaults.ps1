<#
.SYNOPSIS
Clones Core Azure KeyVault Secrets from Source to Target KeyVault.

.DESCRIPTION
This clones all Core Azure KeyVaults Secrets from source to target KeyVault.  The following actions are taken...
    1) csv containing list of valid secret mapping values are read in.  For each mapping item, 5 columns are read in, see details in CSV_File Parameter section
    3) script lists all secrets to be processed, what type of cloning will take place along with a total of how many secrets will be processed.
    4) prompt is deisplayed to allow the user to abort if the sample information does not look right.
    5) If continuing, each valid item is either inserted or updated.  Only existing secrets with different values will be updated.
    6) Action on each item is logged until the script completes.

.EXAMPLE
CopyParseKeyValues_BetweenKeyVaults -CSV_File @("C:\csvTest\VaultCore_Items.csv")
                                    -Source_KeyVaultName "EUWDGTP005AKV01"
                                    -Destination_KeyVaultName "USEDGTP004AKV01"

.PARAMETER CSV_File
This is the csv that contains the list of valid core vault names that need to be cloned from the Source to Destination KeyVault.  The columns are as follows...
    1) "SrcKeyName" - contains the key name that must be present in the Source KeyVault.
    2) "DestKeyName" - contains the name key name in the Destination KeyVault where the source secret is written (typically the SrcKeyName and DestKeyName are the same).
    3) "ParamMatch" - this contains the name of the parameter that is selectively cloned into the destination key value from the source.  
            For example, if "Password" was the value here, the only the password value would be cloned into the destination value.
    4) "ParamDelimiter" - contains the delimiter used separate the parameters in the key value.
    4) "OptionalNote" - free form test field for notes.

.PARAMETER Source_KeyVaultName
Resource name of Source KeyVault.

.PARAMETER Destination_KeyVaultName
Resource name of Destination KeyVault

#>
#
# ParseKeyVaultValue.ps1
#
# Dev Environment
#   Source: EUWDGTP005AKV01
#     Dest: USEDGTP004AKV01
#
# Stage Environment
#   Source: EUWXGTP020AKV01
#     Dest: USEXGTP021AKV01
# 
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [string]$CSV_File = "C:\csvTest\TestDr\VaultClone_testdoc.csv",
    [Parameter(Mandatory=$False)]
	[string]$Source_KeyVaultName = "zzzEUWDGTP005AKV01",
	[Parameter(Mandatory=$False)]
	[string]$Destination_KeyVaultName = "zzzUSEDGTP004AKV01"
)

# Functions
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


$destStringItems = $null;
$keyNames = import-csv $CSV_File;

#List Values that will be processed
Write-Host "Cloning the following keyNames from $Source_KeyVaultName to $Destination_KeyVaultName";
foreach ($keyName in $keyNames)
{
    $wrkFromName = $keyName.("SrcKeyName");
    $wrkToName = $keyName.("DestKeyName");
    $wrkParamMatch = $keyName.("ParamMatch");
    $wrkParamDelimiter = $keyName.("ParamDelimiter");
    $wrkNote = $keyName.("OptionalNote");
    if ("" -ne $wrkParamMatch)
    {
        Write-Host "Vault Key Added to List: '$wrkFromName' to '$wrkToName' with partial replace on '$wrkParamMatch' value, Note: ($wrkNote)";
    }
    else
    {
        Write-Host "Vault Key Added to List: '$wrkFromName' to '$wrkToName', full clone, Note: ($wrkNote)";        
    }

}

#Confirm You want to proceed
Write-Host "";
$wrkCount = $keyNames.Count;
$inputAnswer =  Read-Host -Prompt "$wrkCount key names found, Continue with cloning them (yes, no)?";

if ($inputAnswer -ne 'yes')
{
    Write-Host "Script aborted per user response";
    exit;
}

#Process each item in spreadsheet
foreach ($keyName in $keyNames)
{    
    $sourceObj = $null;
    $destObj = $null;
    $wrkSrcSecretName = $keyName.("SrcKeyName");
    $wrkDestSecretName = $keyName.("DestKeyName");
    $wrkParamMatch = $keyName.("ParamMatch");
    $wrkParamDelimiter = $keyName.("ParamDelimiter");
    if ((-not [string]::IsNullOrWhiteSpace($wrkSrcSecretName)) -and (-not [string]::IsNullOrWhiteSpace($wrkDestSecretName)))
    {
        $sourceObj = Get-AzKeyVaultSecret -VaultName $Source_KeyVaultName -Name $wrkSrcSecretName;
        $destObj = Get-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName;
        
        $isExist = KeyValuesAreSame $sourceObj $destObj;
        if ($true -eq $isExist)
        {
            Write-Host  "**** $wrkSrcSecretName not cloned: Key values are same ****";
            continue;
        }

        $isUpserted = $false;
        if ($null -ne $destObj){
		    $isUpserted = $true;
	    }
    }

    if ($null -ne $sourceObj){
	    if ($null -ne $destObj){
		    $isUpserted = $true;
        }

        #If no parameter match, clone source secret into DestSecretName
        if ("" -eq $wrkParamMatch)
        {
            Set-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName -SecretValue $sourceObj.SecretValue;
            if ($false -eq $isUpserted)
            {
                Write-Host "Successfully cloned '$wrkSrcSecretName' to '$wrkDestSecretName'";
            }
            else
            {
                Write-Host "Successfully cloned '$wrkSrcSecretName' to '$wrkDestSecretName' (update)";
            }

        }
        else 
        #if Parameter given, replace only parameter in the existing destination keyname
        {
            $srcResults = $null;
            #Write-Host "source value is $sourceObj.SecretValueText";
            $stringItems = $sourceObj.SecretValueText.Split($wrkParamDelimiter);
            $srcResults = $stringItems | Select-String -Pattern $wrkParamMatch ;           

            if ($null -ne $destObj)
            {
                if ($null -ne $srcResults)
                {
                    $destStringItems = $destObj.SecretValueText.Split($wrkParamDelimiter);
                    $destResults = $destStringItems | Select-String -Pattern $wrkParamMatch ;
                    if ($null -ne $destResults)
                    {
                        $destStringItems[$destResults.LineNumber-1] = $srcResults.Line;
                        $newDestSecretText = ($destStringItems -join ';');
                        $newDestSecureText = ConvertTo-SecureString $newDestSecretText -AsPlainText -Force;
                        Set-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $destObj.Name -SecretValue $newDestSecureText;
                        Write-Host "Successfully copied '$wrkParamMatch' value from to '$wrkSrcSecretName' to '$wrkDestSecretName'";    
                    }
                    else 
                    {
                        Write-Host "Unsuccessful clone '$wrkParamMatch' value does not exist ('$wrkSrcSecretName' to '$wrkDestSecretName')";    
                    }
                }
            }
        }
    }
    else 
    {
        Write-Host  "**** $wrkSrcSecretName not cloned: Does not exist in source Key Vault ****";
        
    }
}

Write-Host "done";
