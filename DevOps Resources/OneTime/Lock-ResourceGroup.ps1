<#
.SYNOPSIS
     Create resource locks for resource groups in a given subscription  

.DESCRIPTION
    List all subscriptions then filters by the using the tags on the resource grougs 

.NOTES
Modify  the "$subscriptionNameLike" 

.EXAMPLE
    .\Lock-ResourceGroups.ps1

#>

$subscriptionNameLike = "*PROD*"

#Connect-AzAccount

function ResourceGroupsLock {
    # Get all subscriptions
    $subscriptions = Get-AzSubscription 
    #loop through every subscription 
    foreach ($subscription in $subscriptions) {
        #filters subscription by name 
        if ($subscription.name -like $subscriptionNameLike) {
            Write-Host $subscription.Name
            Select-AzSubscription -SubscriptionObject $subscription
            #Construct array of resource group in the subscription and filter by Tag
            $resourceGroups = Get-AzResourceGroup | Where-Object {$_.Tags.ENVIRONMENT -contains 'Production'}
            #loops through the resource groups and sets the resource lock on each resource group 
            foreach ($resourceGroup in $resourceGroups) {
                Write-Host "Processing: " $resourceGroup.ResourceGroupName -ForegroundColor Yellow
                #$resourceLockStatus = Get-AzResourceLock -ResourceGroupName $resourceGroup.ResourceGroupName
                #Remove-AzResourceLock -LockName "prod-lock" -ResourceGroupName $resourceGroup.ResourceGroupName -Force
                #Set-AzResourceLock -LockName "prod-lock" -LockLevel CanNotDelete -LockNotes "This lock is created to prevent accidental deletion" -ResourceGroupName $resourceGroup.ResourceGroupName -Force
                Write-Host $resourceGroup.ResourceGroupName "Lock has been set succesfully" -ForegroundColor Green
            }

        }
    }   
}


#Execute the function 
ResourceGroupsLock

