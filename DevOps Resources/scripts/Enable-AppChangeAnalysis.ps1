Param(
    [Parameter(Mandatory = $true)]
    [String] $subscriptionId= "",
    [Parameter(Mandatory = $true)]
    [String] $resourceGroupName = ""
)
# Make Feature Flag visible to the subscription
Set-AzContext -SubscriptionId $subscriptionId
# Register resource provider
Register-AzResourceProvider -ProviderNamespace "Microsoft.ChangeAnalysis"
# Enable each web app for the ResourceGroup Specified
$webapp_list = Get-AzWebApp | Where-Object {$_.ResourceGroup -eq $resourceGroupName}
foreach ($webapp in $webapp_list)
{
   $tags = $webapp.Tags
   $tags[“hidden-related:diagnostics/changeAnalysisScanEnabled”]=$true
   Set-AzResource -ResourceId $webapp.Id -Tag $tags -Force
}