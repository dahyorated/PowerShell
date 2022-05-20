Function Get-ApplicationIdFromStageName
{
	<#
	.Synopsis
	Gets the application ID for the specified stage name.

	.Description
	The Get-ApplicationIdFromStageName function gets the application ID for the -StageName stage name.

	.Parameter StageName
	This is a DevOps standard stage name.

	.Parameter UseCore
	If specified, this gets the Core application ID. Otherwise, it gets the tenant application Id. -UseCore can be used in a test setup where you need the client secret and client id to test some pipeline scripts.

	.Outputs
	This methods returns the application ID (which is a GUID) as a string.
	#>
	param(
		[Parameter(Mandatory=$false)]
		[string]$StageName = $ENV:RELEASE_ENVIRONMENTNAME,
		[switch]$UseCore
	)
	if ([string]::IsNullOrWhiteSpace($StageName))
	{
		$message = "No value was provided for [RELEASE_ENVIRONMENTNAME]";
		Stop-ProcessError $message;
	};
	if ($UseCore)
	{
		$applicationId = switch ($StageName)
		{
			"DEV-EUW" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"DEV-USE" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"DMO-EUW" {"347e83e0-ca4a-486d-8fbe-bed51d902a4a"}
			"PRD-EUW" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"PRD-USE" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"PRF-EUW" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"QAT-EUW" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"STG-EUW" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"STG-USE" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
			"UAT-EUW" {"0d0d30ab-a5fd-4a60-90e1-07e50a483d10"}
		}
	}
	else
	{
		$applicationId = switch -Regex ($StageName)
		{
			"^(DMO|STG|PRD)-(EUW|USE)$"
			{
				(Get-AzADServicePrincipal -DisplayName 'CTP-CoDev-TAX-GTP_PROD-AUT-P01').ApplicationId.Guid
			}
			"^(DEV|QAT|UAT|PRF)-(EUW|USE)$"
			{
				(Get-AzADServicePrincipal -DisplayName 'CTP-CoDev-TAX-GTP_NONPROD-AUT-P01').ApplicationId.Guid
			}
			default {""}
		};
	}
	return $applicationId;
}
