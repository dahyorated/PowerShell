<#
.SYNOPSIS
Give Azure Data Share service permission to storage account to share data.

.DESCRIPTION
The script assigns MSI on Storage accounts and enable them to be accessed by the Azure Data Share service. 'read' Role is assigned to Azure Data Share Account for your source storage account where data is shared from. 'write' Role is assigned to Azure Data Share Account for your target storage account where data is written into.

.EXAMPLE
./AssignPermission.ps1 -DataShareAccountResourceId '/subscriptions/<SubscriptionID>/resourcegroups/<ResourceGroupName>/providers/Microsoft.DataShare/accounts/<DataShareAccountName>' -StorageAccountResourceId '/subscriptions/<SubscriptionID>/resourcegroups/<ResourceGroupName>/providers/Microsoft.Storage/storageAccounts/<StorageAccountName>'-Role 'read/write'"
#>

# Copyright (c) Microsoft.  All rights reserved.
param(
    [Parameter(Mandatory = $true)]
    [string]
    #/subscriptions/<subscription>/resourceGroups/<resourgegroup>/providers/Microsoft.DataShare/accounts/<DataShareAccount>
    $DataShareAccountResourceId = $global:DataShareAccountResourceId,
    [Parameter(Mandatory = $true)]
    [string]
    $StorageAccountResourceId = $global:StorageAccountResourceId,
    [Parameter(Mandatory = $true)]
    [ValidateSet('read', 'write')]
    [string]
    $Role = $global:Role
)

function Get-RbacRole($Role) {
    switch ($Role) {
        # Storage Blob Data Reader (Preview)
        "read" {"2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"; break}
        # Storage Blob Data Contributor (Preview)
        "write" {"ba92f5b4-2d11-453d-a403-e96b0029c9fe"; break}
        default {"Invalid Role"; throw 'Invalid Role'}
    }
}

#function Install-AzureAzModule {
#    Write-Host "Installing Az powershell module"
#    Install-Module -Name Az -AllowClobber
#}

#function Validate-AzModule {
#    #Check for Az powershell module
#    if (-not (Get-InstalledModule Az -ErrorAction SilentlyContinue)) {
#        Write-Host "Missing Az powershell module"
#        Install-AzureAzModule
#    }

#    #Check for version Az powershell module
#    if ((Get-InstalledModule -Name Az -AllVersions | select Name, Version | Sort-Object -Descending).Version.ToString() -lt '1.2.1') {
#        Write-Host "Missing Az powershell module version 1.2.1"
#        Install-AzureAzModule
#    }
#}

function Set-SubscriptionContext {
    $azContext = Get-AzContext
    if (-not $azContext) {
        Connect-AzAccount -Subscription $global:Subscription | Out-Null
    }else
    {
        Set-AzContext -SubscriptionId $global:Subscription | Out-Null
    }
}

function Fetch-SubscriptionId {
    $beforeString = "subscriptions/"
    $afterString = "/resourcegroups/"
    $pattern = "$beforeString(.*?)$afterString"
    $datashareAccountResourceIdLower = $DataShareAccountResourceId.ToLower();
    $result = [regex]::Match($datashareAccountResourceIdLower, $pattern)

    $global:Subscription = $result.Groups[1].Value.trim()
}

Try {
    #Validate Powershell Modules Requirements
    #Validate-AzModule

    #Set-SubscriptionId
    Fetch-SubscriptionId

    #Login to Azure account
    Write-Host "Setting the subscription context for subscription-"$global:Subscription
    Set-SubscriptionContext

    #Validate Resources 
    Try
    {
        Get-AzResource -ResourceId $DataShareAccountResourceId -ErrorAction Stop | Out-Null
        Get-AzResource -ResourceId $StorageAccountResourceId -ErrorAction Stop | Out-Null
    }
    Catch
    {
        Throw $_
    }

    #Get DataShare MSI
    Write-Host "Getting the datashare account details"
    $msi = ((Get-AzResource -ResourceId $DataShareAccountResourceId).Identity.PrincipalId)
    Write-Host "Getting Current Role"
    $currentRole = Get-RbacRole($Role)

    Write-Host "checking RoleAssignmentExists"
    #Role Assignment on the storage Account
    $roleAssignmentExists = Get-AzRoleAssignment -ObjectId $msi -RoleDefinitionId $currentRole -Scope $StorageAccountResourceId
    if (-not $roleAssignmentExists) {
        Write-Output "creating new assignment"
         # for debugging from pipeline, removed the | out-null and added -Verbose 
         try {
        New-AzRoleAssignment -ObjectId $msi -RoleDefinitionId $currentRole -Scope $StorageAccountResourceId -Verbose
         }
         catch 
         {
             Write-Output "error in new role assignment"
             Write-Output "error: " + $_;
         }
       Write-Output "Permission assigned"
    }
    else {
        Write-Output "Permission already exists"
    }
}
Catch {
    Write-Host "Failed to assign permission"
    Write-Error $_.Exception.Message
}