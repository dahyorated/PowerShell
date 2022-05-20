<#
.Synopsis
Create or update an event grid subscription for an Azure function.

.Description
The Set-EventGridSubscription script creates or updates an event grid subscription for the -FucntionName Azure function.

This is a replacement for GetTokenFunction (in "src\EY\GTP\IAC\BuildScripts\VSTSRMScripts\VSTSRMScripts").

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

.Parameter SubscriptionName
This is the Azure subscription for the -TopicName topic.

.Parameter EventType
This is a ":" separated list of event types to be handled by the subscription.

.Parameter eventTTL
This is the time to live for the subscription.

.Parameter maxDeliveryAttempt
This is the maximum delivery attempts to be made.

.Parameter deadLetter
Boolean to indicate whether to have a deadletter queue

.Parameter deadLetterStorageAccount
storage account name for deadletter queue.  Container will be in the format of  "deadletter-{0}-{1}" -f $topicName, $subscriptionName;

.Example
Set-EventGridSubscription `
	-SubscriptionId '5aeb8557-cab7-41ac-8603-9f94ad233efc' `
	-TenantId '5b973f99-77df-4beb-b27d-aa0c70b8482c' `
	-ClientId $clientId `
	-ClientSecret $clientSecret `
	-ResourceGroupName 'GT-WEU-GTP-CORE-DEV-RSG' `
	-AppName 'EUWDGTP005AFA06' `
	-FunctionName 'AlteryxServerListener_HttpTrigger' `
	-TopicName 'euwdgtp005etn01' `
	-SubscriptionName 'euwdev-alteryx' `
	-EventType "InformationRequestStatusUpdated" `
	 -eventTTL "1440" `
	 -maxDeliveryAttempt "30" `
	 -deadLetter $true `
	 -deadLetterStorageAccount "euwdgtp005sta01"

#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
param(
	[Parameter(Mandatory = $true)]
	[string]$subscriptionId,
	[Parameter(Mandatory = $true)]
	[string]$tenantId,
	[Parameter(Mandatory = $true)]
	[string]$clientId,
	[Parameter(Mandatory = $true)]
	[string]$clientSecret,
	[Parameter(Mandatory = $true)]
	[string]$resourceGroupName,
	[Parameter(Mandatory = $true)]
	[string]$appName,
	[Parameter(Mandatory = $true)]
	[string]$functionName,
	[Parameter(Mandatory = $true)]
	[string]$topicName,
	[Parameter(Mandatory = $true)]
	[string]$subscriptionName,
	[Parameter(Mandatory = $true)]
	[string]$eventType,
	[Parameter(Mandatory = $false)]
	[string]$eventTTL,
	[Parameter(Mandatory = $false)]
	[string]$maxDeliveryAttempt,
	[Parameter(Mandatory = $false)]
	[bool]$deadLetter=$false,
	[Parameter(Mandatory = $false)]
	[string]$deadLetterStorageAccount=""

)

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

Write-Output "Starting Set-EventGridSubscription.ps1"


[string[]]$eventTypes = $eventType -split ':';
if ($isVerbose) {
	Write-NameAndValue "Starting GetFunctionToken";
	Write-NameAndValue "subscriptionId" $subscriptionId;
	Write-NameAndValue "tenantId" $tenantId;
	Write-NameAndValue "clientId" $clientId;
	Write-NameAndValue "resourceGroupName" $resourceGroupName;
	Write-NameAndValue "appName" $appName;
	Write-NameAndValue "functionName" $functionName;
	Write-NameAndValue "topicName" $topicName;
	Write-NameAndValue "subscriptionName" $subscriptionName;
	Write-NameAndValue "eventType" $eventType;
	Write-NameAndValue "eventTypeArray[0]" $eventTypes[0];
	Write-NameAndValue "eventTTL" $eventTTL;
	Write-NameAndValue "maxDeliveryAttempt" $maxDeliveryAttempt;
	Write-NameAndValue "deadLetter" $deadLetter;
	Write-NameAndValue "deadLetterStorageAccount" $deadLetterStorageAccount;
}

if ($deadLetter -and [string]::IsNullOrWhiteSpace($deadLetterStorageAccount)) {
	Stop-ProcessError -ErrorMessage "Error - deadletterStorageAccount must be specified if deadletter is true";
}
Write-Verbose "get auth token";
$accessTokenHeader = Get-AzureAdminHeader -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret;
$azBaseUri = "https://management.azure.com";
$azApiVersion = "2016-08-01";
$azResourceType = "Microsoft.Web/sites";
$azResourceId = "/subscriptions/{0}/resourceGroups/{1}/providers/{2}/{3}" -f $subscriptionId,$resourceGroupName,$azResourceType,$appName;
$azAdminBearerTokenEndpoint = "/functions/admin/token";
$adminBearerTokenUri = "{0}{1}{2}?api-version={3}" -f $azBaseUri,$azResourceId,$azAdminBearerTokenEndpoint,$azApiVersion;
$adminBearerToken = Invoke-RestMethod -Method Get -Uri $adminBearerTokenUri -Headers $accessTokenHeader;
Write-Verbose "call management API to get the keys for the function";
$keys = Invoke-RestMethod `
	-Method GET -Headers @{Authorization = ("Bearer {0}" -f $adminBearerToken) } `
	-Uri "https://$appName.azurewebsites.net/admin/functions/$functionName/keys";
$code = $keys.keys[0].value;
Write-Verbose "now we have the uri to call the function";
$funcUri = "https://{0}.azurewebsites.net/api/{1}?code={2}" -f $appName, $functionName, $code;
# create an object for storing values that will get passed to New-AzEventGridSubscription below
$paramObject = @{
	ResourceGroupName     = $resourceGroupName;
	TopicName             = $topicName;
	Endpoint              = $funcUri;
	EventSubscriptionName = $subscriptionName;
	IncludedEventType     = $eventTypes;
};
# check to see if our optional parameters have values.
if (-not [string]::IsNullOrWhiteSpace($eventTTL))
{
	$paramObject.EventTtl = $eventTTL;
}
if (-not [string]::IsNullOrWhiteSpace($maxDeliveryAttempt))
{
	$paramObject.MaxDeliveryAttempt = $maxDeliveryAttempt;
}

if ($deadLetter)
{
	$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $deadLetterStorageAccount;
	$storageid = $storageAccount.Id;
	#container names must be all lowercase
	$containername = ("deadletter-{0}-{1}" -f $topicName, $subscriptionName).ToLower();
	$ctx = $storageAccount.Context;
	try
	{
		$existingContainer = Get-AzStorageContainer -Context $ctx -Name $containername;
	}
	catch
	{
		# swallow exception - if container doesn't exist it throws an exception
		Write-Verbose ("Get-AzStorageContainer: {0}" -f $_.Exception.Message);
	}
	if ($null -eq $existingContainer)
	{
		Write-Output "Creating missing Container: $containerName";
		New-AzStorageContainer -Name $containerName -Context $ctx;
	}
	$deadLetterEndpoint = "$storageid/blobServices/default/containers/$containername"
	$paramObject.DeadLetterEndpoint = $deadLetterEndpoint;
}
Write-Verbose "get list of subscriptions to the Event Grid Topic"
$subscriptions = Get-AzEventGridSubscription -ResourceGroupName $resourceGroupName -TopicName $topicName;
if ($PSCmdlet.ShouldProcess($functionName, "Set subscription")) {
	if ($PSCmdlet.ShouldProcess($functionName, "Set subscription")) {
		if ($isVerbose)
		{
			Write-Output $paramObject;
		}
		try
		{
			if ($subscriptions.PsEventSubscriptionsList.EventSubscriptionName -contains $subscriptionName)
			{
				$mode = "Updating";
				Write-Output "Updating subscription";
				$result = Update-AzEventGridSubscription @paramObject;
			}
			else
			{
				$mode = "Creating";
				Write-Output "Creating subscription";
				$result = New-AzEventGridSubscription @paramObject;
			}
			Write-NameAndValue "Success result" $result.ProvisioningState;
			Write-Output "Results (detailed):";
			$result;
		}
		catch
		{
			$errorMessage = "{0} subscription failed: {1}" -f $mode,$_.Exception.Message
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
	}
	Write-Output "Complete Set-EventGridSubscription.ps1"
}
