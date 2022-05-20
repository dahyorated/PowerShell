<#
.SYNOPSIS
Clones Azure KeyVault Secrets from Source to Target KeyVault that match the entered wildcard string.

.DESCRIPTION
This clones all Core Azure KeyVaults Secrets from source to target KeyVault that match the entered wildcard string.  The following actions are taken...
    1) Using the provided wildcard string, the list of matching key names in the Source KeyVault is created
    3) script lists all the matching secrets along with a total of how many secrets will be processed.
    4) prompt is displayed to allow the user to abort if the sample information does not look right.
    5) If continuing, each valid item is either inserted or updated.  Only existing secrets with different values will be updated.
    6) Action on each item is logged until the script completes.

.EXAMPLE
CopyWildcardKeyValues_BetweenKeyVaults  -MatchString "cosmos*"
                                        -Source_KeyVaultName "EUWDGTP005AKV01"
                                        -Destination_KeyVaultName "USEDGTP004AKV01"

.PARAMETER MatchString
This is a string where you can do either an exact or wildcard match.

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
    [string]$MatchString = "cosmos-cosmosconnection*",
    [Parameter(Mandatory=$False)]
	[string]$Source_KeyVaultName = "EUWDGTP005AKV01",
	[Parameter(Mandatory=$False)]
	[string]$Destination_KeyVaultName = "USEDGTP004AKV01"
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

Write-Host "Search $Source_KeyVaultName keyvault for matches with '$MatchString'";
$keyVaultList = New-Object System.Collections.ArrayList;
Get-AzKeyVaultSecret -VaultName $Source_KeyVaultName | ? Name -Like $MatchString | %{ $key = Get-AzKeyVaultSecret -VaultName $Source_KeyVaultName -Name $_.Name;    
    $keyVaultList.Add($key) | Out-Null;};

#List Values that will be processed
Write-Host "Cloning the following keyNames from $Source_KeyVaultName to $Destination_KeyVaultName";
foreach ($keyVaultItem in $keyVaultList)
{
    $wrkFromName = $keyVaultItem.Name;
    $wrkToName = $wrkFromName;
    Write-Host "Vault Key Added to List: '$wrkFromName' to '$wrkToName', full clone";        
}

#Confirm You want to proceed
Write-Host "";
$wrkCount = $keyVaultList.Count;
$inputAnswer =  Read-Host -Prompt "$wrkCount key names found, Continue with cloning them (yes, no)?";

if ($inputAnswer -ne 'yes')
{
    Write-Host "Script aborted per user response";
    exit;
}

#Process each item in spreadsheet
foreach ($keyVaultItem in $keyVaultList)
{    
    $sourceObj = $null;
    $destObj = $null;
    $wrkSrcSecretName = $keyVaultItem.Name;
    $wrkDestSecretName = $wrkSrcSecretName;

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

    #Set-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName -SecretValue $sourceObj.SecretValue;
    if ($false -eq $isUpserted)
    {
        Write-Host "Successfully cloned '$wrkSrcSecretName' to '$wrkDestSecretName'";
    }
    else
    {
        Write-Host "Successfully cloned '$wrkSrcSecretName' to '$wrkDestSecretName' (update)";
    }
}

Write-Host "done";
