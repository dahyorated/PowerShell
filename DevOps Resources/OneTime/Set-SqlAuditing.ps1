<#
.SYNOPSIS
Script to enabled Sql Server Auditing

.DESCRIPTION
This script iterates through the list of subscrptions to enabled auditing on every instanace 

.PARAMETER Environment
Enviroment to run against

.PARAMETER SubscriptionNames
List of subscriptions to enable auditing on

.Parameter TagName
Name of tag to look for a given tag value

.Parameter TagValue
Tag value to find storage accounts

.EXAMPLE
Set-SqlAuditing.ps1 -Environment "DEV" -SubscriptionNames @('EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP TENANT-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-01-39861197', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-02-39861197')

#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('DEV', 'QA', 'UAT', 'PERF', 'DEMO', 'STG', 'PROD')]
    [string]$Environment,
    [Parameter(Mandatory = $false)]
    [string[]]$SubscriptionNames = @('EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP TENANT-01-39721502', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-01-39861197', 'EY-CTSBP-NON-PROD-TAX-GTP_DEV_TENANT-02-39861197'),
    [Parameter(Mandatory = $false)]  
    [string]$TagName = 'ROLE_PURPOSE',
    [Parameter(Mandatory = $false)]  
    [string]$TagValue = 'Diagnostic Storage Account',
    [Parameter(Mandatory = $false)]  
    [int]$RetentionDays = 365
)

Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;

function Process-Instances($resourceGroupName) {
    
    Write-Host "Resource Group: $resourceGroupName";
    $storageAccount = Get-AzResource -ResourceType "Microsoft.Storage/storageAccounts" -TagName $TagName -TagValue $TagValue -ResourceGroupName $resourceGroupName;   

    if($null -eq $storageAccount){
        Write-Output "No storage accounts with tag: $TagName : $TagValue in Resource Group $resourceGroupName";
        return;
    }

    if ($storageAccount -is [system.array] -and $storageAccount.Length -gt 0 ) {
        $storageAccount = $storageAccount[0];
    }

    $sqlServerInstances = Get-AzSqlServer -ResourceGroupName $resourceGroupName;

    foreach ($instance in $sqlServerInstances) {         
        $sqlAudit = Get-AzSqlServerAudit -ServerObject $instance;
        if ($sqlAudit.BlobStorageTargetState -eq 'Enabled') {
            Write-Output "Sql Audit enabled for $($instance.ServerName)";

            if ($sqlAudit.RetentionInDays -ne $RetentionDays ) {
                Write-Output "Updating rention days to $RetentionDays";

                try {
                    Set-AzSqlServerAudit -ServerName $instance.ServerName -ResourceGroupName $resourceGroupName -RetentionInDays $RetentionDays;
                    Write-Output "Update of retention days on $($instance.ServerName) to $RetentionDays is complete";
                }
                catch {
                    Write-Output "Failed to update retention days on instance $($instance.ServerName)";
                    continue;
                }       
            }
        }
        else {

            try {
                    
                Write-Output "Enabling Sql Audit for $($instance.ServerName) :: Storage Account: $($storageAccount.Name)";
                Set-AzSqlServerAudit -ResourceGroupName $resourceGroupName -ServerName $instance.ServerName -StorageAccountResourceId $storageAccount.ResourceId -BlobStorageTargetState Enabled -RetentionInDays $RetentionDays -ErrorAction Stop;

            }
            catch {
                Write-Output "Failed to enable Audit on instance $($instance.ServerName)";
                continue;
            }

        }
        
    }
}

foreach ($sub in $SubscriptionNames) {
    Set-AzContext $sub;

    if($sub -like "*CAPELLA*") {
        $resourceGroupName = 'GT-WEU-GTP-TENANT-CAPELLA-{0}-RSG' -f $Environment;
        Process-Instances -resourceGroupName $resourceGroupName;

        # Get DR Instances
        if ($Environment -in ('DEV', 'PROD')) {

            $resourceGroupName = 'GT-EUS-GTP-TENANT-CAPELLA-{0}-RSG' -f $Environment;
    
            Process-Instances -resourceGroupName $resourceGroupName;
        }

    } elseif ($sub -like "*TENANT*") {

        $resourceGroupName = 'GT-WEU-GTP-TENANT-{0}-RSG' -f $Environment;
        Process-Instances -resourceGroupName $resourceGroupName;

        # Get DR Instances
        if ($Environment -in ('DEV', 'STG', 'PROD')) {

            $resourceGroupName = 'GT-EUS-GTP-TENANT-{0}-RSG' -f $Environment;
    
            Process-Instances -resourceGroupName $resourceGroupName;
        }

    } else {

        $resourceGroupName = 'GT-WEU-GTP-CORE-{0}-RSG' -f $Environment;
        Process-Instances -resourceGroupName $resourceGroupName;

        # Get DR Instances
        if ($Environment -in ('DEV', 'STG', 'PROD')) {

            $resourceGroupName = 'GT-EUS-GTP-CORE-{0}-RSG' -f $Environment;
    
            Process-Instances -resourceGroupName $resourceGroupName;
        }
    }
}
