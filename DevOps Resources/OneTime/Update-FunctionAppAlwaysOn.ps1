<#
.SYNOPSIS
    ppTo udpate "always on" configuration in a function aa

.DESCRIPTION
    This script updates the "always on" Configuration on function apps

.NOTES
    uncomment line 38 if commented out to run the action

.EXAMPLE
    .\Update-FunctionAppAlwaysOn.ps1 -Environment "DEV" -SubscriptionNames @('EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP TENANT-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-01-39861197', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-02-39861197')

#>

#az login
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [string[]]$SubscriptionNames = @('EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP TENANT-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-01-39861197', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-02-39861197'),
    [Parameter(Mandatory = $true)]
    [ValidateSet('DEV', 'QA', 'UAT', 'PERF', 'DEMO', 'STG', 'PROD')]
    [string]$Environment
)

function Process-Functionapp($resourceGroupName) {
    
    Write-Host "Resource Group: $resourceGroupName";

    $fu = az functionapp list --resource-group $resourceGroupName --query "[].{name: name}"
    $jsonObj = $fu | ConvertFrom-Json
    $functionAppName = $jsonObj.name
    

    foreach ($functionapp in $functionAppName){

   Write-host "setting config for $functionApp" $resourceGroupName
   #az functionapp config set --always-on true --name $functionapp --resource-group $resourceGroupName
   #Write-host "Done with always on setting config for $functionApp"
            }
    
    }

foreach ($sub in $SubscriptionNames) {
    az account set --subscription $sub;

    if($sub -like "*CAPELLA*") {
        $resourceGroupName = 'GT-WEU-GTP-TENANT-CAPELLA-{0}-RSG' -f $Environment;
        Process-Functionapp -resourceGroupName $resourceGroupName;

        # Get DR Instances
        if ($Environment -in ('DEV', 'PROD')) {

            $resourceGroupName = 'GT-EUS-GTP-TENANT-CAPELLA-{0}-RSG' -f $Environment;
    
            Process-Functionapp -resourceGroupName $resourceGroupName;
        }

    } elseif ($sub -like "*TENANT*") {

        $resourceGroupName = 'GT-WEU-GTP-TENANT-{0}-RSG' -f $Environment;
        Process-Functionapp -resourceGroupName $resourceGroupName;

        # Get DR Instances
        if ($Environment -in ('DEV', 'STG', 'PROD')) {

            $resourceGroupName = 'GT-EUS-GTP-TENANT-{0}-RSG' -f $Environment;
    
            Process-Functionapp -resourceGroupName $resourceGroupName;
        }

    } else {

        $resourceGroupName = 'GT-WEU-GTP-CORE-{0}-RSG' -f $Environment;
        Process-Functionapp -resourceGroupName $resourceGroupName;

        # Get DR Instances
        if ($Environment -in ('DEV', 'STG', 'PROD')) {

            $resourceGroupName = 'GT-EUS-GTP-CORE-{0}-RSG' -f $Environment;
    
            Process-Functionapp -resourceGroupName $resourceGroupName;
        }
    }
}
