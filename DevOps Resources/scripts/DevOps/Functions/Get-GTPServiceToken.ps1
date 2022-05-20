<#
.Synopsis
Get a GTP JWT Token for service to service authentication.

.Description
This script calls the User Service endpoint to get a Service Token.  The service name can be provided (otherwise defaults to provisioning service). Either
- The -KeyVault value can be provided (and the service will lookup the secret); or
- The secret can be directly provided

.Parameter ServiceID
Service ID to use - will default to provisioningservice.

.Parameter AuthService
URL to the user (authentication service).

.Parameter ServiceAuthSecret
If provided, this is the Auth Secret to use for the service call. If empty will be retrieved from -KeyvVault.

.Parameter KeyVault
If specified and -ServiceAuthSecret is not provided, will get the service auth secret in format of (XXX-ServiceAuthSecret where XX is the value of $ServiceID).

.Example
$token = Get-GTPServiceToken -KeyVault EUWDGTP005AKV01 -AuthService https://userservice-dev.sbp.eyclienthubd.com;

This gets the token using keyvault EUWDGTP005AKV01.

.Example
$token = Get-GTPServiceToken -ServiceAuthSecret "thisisasecret" EUWDGTP005AKV01 -AuthService https://userservice-dev.sbp.eyclienthubd.com;

This gets the token using a secret.

#>
Function Get-GTPServiceToken
{
	[CmdletBinding()]
	Param(
		[Parameter()]
		[String]
		$ServiceID = "provisioningservice",
		[Parameter(Mandatory = $true)]
		[String]$AuthService,
		[String]$ServiceAuthSecret,
		[String]$KeyVault
	)
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
	if ([string]::IsNullOrEmpty($KeyVault) -and $ServiceAuthSecret -eq "")
	{
		$errorMessage = "invalid parameters - either keyvault or service authsecret required";
		Stop-ProcessError -errorMessage $errorMessage;
	}
	if ($ServiceAuthSecret -eq "")
	{
		$secretName = $ServiceID + "-ServiceAuthSecret";
		$ServiceAuthSecret = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name $secretName).SecretValueText;
	}
	Write-Verbose "Getting Client Configurations for  ServiceID $ServiceID AuthService $AuthService ClientService $ClientService";
	# Get service auth token
	$serviceLogin = @{
		serviceId = $ServiceID
		secret    = $ServiceAuthSecret
	};
	# Specify we only need a short-lived token
	$headers = @{
		"X-Token-Expiration-Minutes" = "15"
		"Accept"                     = "application/json"
		"Content-Type"               = "application/json"
	};
	Write-Verbose  "Getting token from AuthService";
	$response = Invoke-RestMethod -Method Post -Uri "$AuthService/api/v2/authenticate/service" -Body (ConvertTo-Json $serviceLogin -Depth 100 -Compress) -Headers $headers -ContentType "application/json";
	$gtpToken    = $response.token;
	return $gtpToken;
}
