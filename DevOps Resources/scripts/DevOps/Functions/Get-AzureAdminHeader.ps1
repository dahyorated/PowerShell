<#
.Synopsis
Gets a Header for Azure Management REST calls.

.Description
The Get-AzureAdminHeader function, using input from an SPN, calls the Azure Management Core Endpoint to get a Bearer Token to format a Header to make management calls.

.Parameter ClientId
This is the ID for authentication.

.Parameter ClientSecret
This is the client secret for authentication.

#>
Function Get-AzureAdminHeader
{

	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$tenantId,
		[Parameter(Mandatory = $true)]
		[string]$clientId,
		[Parameter(Mandatory = $true)]
		[string]$clientSecret
		
	)
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
	$authUri = "https://login.microsoftonline.com/{0}/oauth2/token?api-version=1.0" -f $tenantId;
	$resourceUri = "https://management.core.windows.net/";
	Write-Verbose "get auth token";
	$authRequestBody = @{
		grant_type    = "client_credentials";
		resource      = $resourceUri;
		client_id     = $clientId;
		client_secret = $clientSecret;
	};
	$auth = Invoke-RestMethod -Uri $authUri -Method Post -Body $authRequestBody;
	Write-Verbose "get bearer token";
	$accessTokenHeader = @{ "Authorization" = ("Bearer {0}" -f $auth.access_token) };
	return $accessTokenHeader;
}
