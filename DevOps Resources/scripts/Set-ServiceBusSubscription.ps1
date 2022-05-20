<#
.Synopsis
Create or update service bus subscriptions.

.Description
The Set-ServiceBusSubscription script creates or updates the -Subscriptions service bus subscriptions.

.Parameter NameSpace
This is the namespace for the subscriptions.

.Parameter ResourceGroup
This is the resource group name for the subscriptions.

.Parameter Subscriptions
This is the set of subscription to create or update.

.Parameter Filters
This is the set of filter to create or update.

.Parameter RequiresSession
This is $true if the subscriptions require duplicate detection.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
Param(
	[Parameter(Mandatory=$true)]
	[string]$NameSpace,
	[Parameter(Mandatory=$true)]
	[string]$ResourceGroup,
	[Parameter(Mandatory=$true)]
	[hashTable]$Subscriptions,
	[Parameter(Mandatory=$false)]
	[hashTable]$Filters = @{},
	[Parameter(Mandatory=$false)]
	[bool]$RequiresSession = $true
)
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$out = $Subscriptions | Out-String;
$out2 = $Filters | Out-String;
Write-Output "CreateServiceBusSubscription -nameSpace $NameSpace -resourceGroup $ResourceGroup -subscriptions $out -filters $out2";
$ErrorActionPreference = "Stop";
#get namespace - this will cause script to fail if it doesn't exist
$currentNamespace = Get-AzServiceBusNamespace -ResourceGroup $ResourceGroup -NamespaceName $NameSpace;
foreach ($subscriptionName in $Subscriptions.Keys) {
	$cnt++;
	$topicName = $Subscriptions[$subscriptionName];
	$message = "Creating or updating subscription {0} in topic {1}" -f $subscriptionName,$topicName;
	if ($PSCmdlet.ShouldProcess($message))
	{
		Write-Output $message;
		New-AzServiceBusSubscription -ResourceGroup $resourceGroup -NamespaceName $NameSpace -TopicName $topicName -SubscriptionName $subscriptionName -RequiresSession $RequiresSession -DeadLetteringOnMessageExpiration $true;
		if ($Filters.ContainsKey($subscriptionName))
		{
			$ruleName = $subscriptionName + "Rule";
			New-AzServiceBusRule -ResourceGroupName $resourceGroup -Namespace $NameSpace -Topic $topicName -Subscription $subscriptionName -Name $ruleName -SqlExpression $Filters[$subscriptionName];
		}
	}
}
Write-Output ("{0} Subscriptions processed" -f $cnt);
