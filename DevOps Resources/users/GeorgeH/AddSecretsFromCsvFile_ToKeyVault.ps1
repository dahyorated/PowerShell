<#
.SYNOPSIS
Reads list of Secrets and Value from csv file and upserts them into Target KeyVault.

.DESCRIPTION
Reads list of Secrets and Value from csv file and upserts them into Target KeyVault.  The following actions are taken...
    1) csv containing list of secrets keys and values.
    3) script lists all secrets to be upserted along with the total of how many secrets will be processed.
    4) prompt is deisplayed to allow the user to abort if the information does not look right.
    5) If continuing, each item is either inserted or updated.  Existing secrets with identical values WILL NOT be updated. 
    6) Action on each item is logged until the script completes.

.EXAMPLE
AddSecretsFromCsvFile_ToKeyVault    -CsvFile @("C:\csvTest\\NewKeyVaultItems.csv")
                                    -Destination_KeyVaultName "USEDGTP004AKV01"


.PARAMETER CsvFile
This is the csv that contains the list of key names and corresponding values to be upserted into the destination keyvault.  The columns are as follows...
    1) "KeyName" - contains secret name.
    2) "KeyValue" - contains secret value in non-secure form.
    3) "KeyType" - contains secret type in non-secure form.

.PARAMETER Destination_KeyVaultName
Resource name of Destination KeyVault

#>

#
# AddSecretsFromCsvFile_ToKeyVault.ps1
#
# Dev Environment: EUWDGTP005AKV01
# 
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [string]$CsvFile = "C:\csvTest\NewKeyVaultItems.csv",
	[Parameter(Mandatory=$False)]
	[string]$Destination_KeyVaultName = "xxxEUWDGTP005AKV01"
)

# Functions

function KeyValuesAreSame{
    param (
        [string]$secretText,
        [System.Object]$dstObj
    )    

    if ($null -eq $dstObj){
        return $false;
    }

    if ($secretText -eq $dstObj.SecretValueText){
        return $true;
    }

    return $false;
}


# Main Logic
$keyNames = import-csv $CsvFile;

#List KeyNames that will be processed
Write-Host "Adding KeyNames to $Destination_KeyVaultName";
foreach ($keyName in $keyNames)
{
    $wrkKeyName = $keyName.("KeyName");
    Write-Host "Key Name to be processed: '$wrkKeyName'";        
}

#Confirm You want to proceed
Write-Host "";
$wrkCount = $keyNames.Count;
$inputAnswer =  Read-Host -Prompt "You will be processing $wrkCount keys, Continue with processing them (yes, no)?";

if ($inputAnswer -ne 'yes')
{
    Write-Host "Script aborted per user response";
    exit;
}

#Process each item for each tenant found in spreadsheets
foreach ($keyName in $keyNames)
   {
       $destObj = $null;
       
       #build KV keyName
       $wrkDestSecretName = $keyName.("KeyName");
       $newDestSecretText = $keyName.("KeyValue");
       $newDestSecretType = $keyName.("KeyType");    

       if (-not [string]::IsNullOrWhiteSpace($wrkDestSecretName))
       {
           # get destination information; don't upsert if the same
           $destObj = Get-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName;
           $isExist = KeyValuesAreSame $newDestSecretText $destObj;
           if ($true -eq $isExist)
           {
               Write-Host  "**** $wrkDestSecretName not updated: Key values are same ****";
               continue;
           }

           $newDestSecureText = ConvertTo-SecureString $newDestSecretText -AsPlainText -Force;
           Set-AzKeyVaultSecret -VaultName $Destination_KeyVaultName -Name $wrkDestSecretName -SecretValue $newDestSecureText -ContentType $newDestSecretType;

           if ($null -eq $destObj){
               Write-Host "Successfully inserted '$wrkDestSecretName'";
            }
            else {
                Write-Host "Successfully updated '$wrkDestSecretName'";                
            }
        }
    }

Write-Host "done";
