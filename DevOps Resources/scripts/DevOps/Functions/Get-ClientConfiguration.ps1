<#
.Synopsis
Get client configurations for an environment.

.Description
This script will first call Get-GTPServiceToken to get a GTP Service-to-Service JWT token, then will call the client service endpoints to get all configurations

.Parameter ServiceID
Service ID to use - will default to provisioningservice

.Parameter AuthService
URL to the user (authentication service)

.Parameter ClientService
URL to the Client Service

.Parameter ServiceAuthSecret
If provided the Auth Secret to use for the service call.  If empty will be retrieved from KeyvVault

.Parameter KeyVault
If entered and ServiceAuthSecret not provided, will get service auth secret in format of (XXX-ServiceAuthSecret where XX is the value of $ServiceID)

.Parameter ClientId
If entered - get configuration only for specified client ID - otherwise get all

.Example
Get All client configurations for Dev ENV
$configs = Get-ClientConfiguration -ClientService https://euwdgtp005wap0w.azurewebsites.net/ -KeyVault EUWDGTP005AKV01 -AuthService https://userservice-dev.sbp.eyclienthubd.com;

#>
Function Get-ClientConfiguration
{
	[CmdletBinding()]
	Param(
		[Parameter()]
		[String]
		$ServiceID = "provisioningservice",
		[Parameter(Mandatory = $true)]
		[String]$AuthService,
		[Parameter(Mandatory = $true)]
		[String]$ClientService,
		[String]$ServiceAuthSecret,
		[String]$KeyVault,
		[int]$ClientId=0
	)

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
	$gtpToken = Get-GTPServiceToken -ServiceID $ServiceID -KeyVault $KeyVault -AuthService $AuthService -ServiceAuthSecret $ServiceAuthSecret ;
	# Get configuration data for all clients
	$authHeaders = @{
		Authorization = "Bearer $gtpToken"
		"Accept"      = "application/json";
	}
	if ($ClientId -eq 0)
	{
		Write-Verbose "Getting all client configurations from client service";
		$clientConfigs = Invoke-RestMethod -Method Get -Uri "$ClientService/api/client/configuration" -Headers $authHeaders;
	}
	else
	{
		Write-Verbose "Getting all client configurations from client service";
		$clientConfigs = Invoke-RestMethod -Method Get -Uri "$ClientService/api/client/$clientId/configuration" -Headers $authHeaders;
	}
	$sorted = $clientConfigs | Sort-object -Property "clientId";
	return $sorted;
}
