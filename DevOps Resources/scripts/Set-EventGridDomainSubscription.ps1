<#
.Synopsis
Create or update an event grid domain subscription for an Azure function with event grid binding.

.Description
The Set-EventGridDomainSubscription script creates or updates an event grid subscription for the -FucntionName Azure function.

.Parameter subscriptionId
This is the ID of the subscription containing the deployed -functionName;

.Parameter TenantId
This is the Azure tenant ID.

.Parameter ClientId
This is the ID for authentication.

.Parameter ClientSecret
This is the client secret for authentication.

.Parameter ResourceGroupName
This is the resource group containing -FunctionName.

.Parameter AppName
This is the app service hosting -FucntionName.

.Parameter FunctionName
This is the function name

.Parameter TopicName
This is the topic name for the subscription.

.Parameter DomainName
This is the Event Grid Domain name for the subscription.

.Parameter SubscriptionName
This is the Azure subscription for the -TopicName topic.

.Parameter EventTypes
This is a ":" separated list of event types to be handled by the subscription.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[string]$subscriptionId,
	[Parameter(Mandatory=$true)]
	[string]$tenantId,
	[Parameter(Mandatory=$true)]
	[string]$clientId,
	[Parameter(Mandatory=$true)]
	[string]$clientSecret,
	[Parameter(Mandatory=$true)]
	[string]$resourceGroupName,
	[Parameter(Mandatory=$true)]
	[string]$appName,
	[Parameter(Mandatory=$true)]
	[string]$functionName,
	[Parameter(Mandatory=$true)]
	[string]$topicName,
	[Parameter(Mandatory=$true)]
	[string]$domainName,
	[Parameter(Mandatory=$true)]
	[string]$subscriptionName,
	[Parameter(Mandatory=$true)]
	[string]$eventTypes
)

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
Write-Output "Starting Set-EventGridDomainSubscription"
if ($isVerbose)
{
	Write-NameAndValue "Starting GetFunctionToken";
	Write-NameAndValue "subscriptionId" $subscriptionId;
	Write-NameAndValue "tenantId" $tenantId;
	Write-NameAndValue "clientId" $clientId;
	Write-NameAndValue "resourceGroupName" $resourceGroupName;
	Write-NameAndValue "appName" $appName;
	Write-NameAndValue "functionName" $functionName;
	Write-NameAndValue "domainName" $domainName
	Write-NameAndValue "topicName" $topicName;
	Write-NameAndValue "subscriptionName" $subscriptionName;
	Write-NameAndValue "eventTypes" $eventTypes;
	
}
Write-Verbose "get auth token";
$accessTokenHeader = Get-AzureAdminHeader -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret;
$topicResourceName = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.EventGrid/Domains/{2}/topics/{3}" `
	-f $subscriptionId, $resourceGroupName, $domainName, $topicName;
$functionResourceName = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Web/sites/{2}/functions/{3}" `
	-f $subscriptionId, $resourceGroupName, $appName, $functionName;
[array]$eventTypeArray = $eventTypes.Split(":");
$functionLabel = "functions-{0}" -f $functionName.ToLower();
# create an object for storing values that will get passed to New-AzEventGridSubscription below
$paramObject = @{
	name = $subscriptionName;
	properties = @{
		"topic" = $topicResourceName;
		"destination" = @{
			"endpointType" =  "AzureFunction";
			"properties" = @{
				"resourceId" = $functionResourceName;
				"maxEventsPerBatch"= 1;
				"preferredBatchSizeInKilobytes" = 64;
			}
		}
		"filter" = @{
				"includedEventTypes" =  $eventTypeArray;
				"advancedFilters" = @();
			}
		"lables" = @($functionLabel);
		"eventDeliverySchema" =  "EventGridSchema";
	}
}

$json = $paramObject | ConvertTo-Json -Depth 5 ;

$mangementURI = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.EventGrid/Domains/{2}/topics/{3}/providers/Microsoft.EventGrid/eventSubscriptions/{4}?api-version=2020-04-01-preview" `
		-f $subscriptionId, $resourceGroupName, $domainName, $topicName, $subscriptionName;
if ($PSCmdlet.ShouldProcess($subscriptionName,"Create/Update Domain Subscription"))
{
	try
	{
		$res = Invoke-RestMethod `
			-Method Put -Headers $accessTokenHeader `
			-Uri $mangementURI `
			-Body $json `
			-ContentType "application/json";
		if ($isVerbose) {
			write-output ($res | ConvertTo-Json -Depth 100);
		}
			#TODO - check $res
	}
	catch
	{
		$errMsg = "Fail to call REST Endpoint: {0}" -f $_.Exception.Message;
		Stop-ProcessError $errMsg;
	}
}

Write-Output "Finished Set-EventGridDomainSubscription";
