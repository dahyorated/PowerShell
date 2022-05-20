Function Get-GatewaySubscriptionFromStageName
{
	<#
	.Synopsis
	Gets the subscription where the app Gateways exist for the specified stage name.

	.Description
	The Get-GatewaySubscriptionFromStageName function gets the key vault name for the -StageName stage name.

	.Parameter StageName
	This is a DevOps standard stage name. This is a required parameter.
	#>
	param(
		[Parameter(Mandatory=$false)]
		[ValidatePattern('(DEV|QAT|UAT|DMO|PRF|STG|PRD)-(EUW|USE)')]
		[string]$StageName
	)
	if ([string]::IsNullOrWhiteSpace($StageName))
	{
		$message = "No value was provided for [RELEASE_ENVIRONMENTNAME]";
		Stop-ProcessError $message;
	}
	$subscriptionName = $null;
	$subscriptionName = switch ($StageName)
	{
		'DEV-EUW' {"EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502"}
		'QAT-EUW' {"EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502"}
		'UAT-EUW' {"EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502"}
		'PRF-EUW' {"EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502"}
		'DMO-EUW' {"EY-CTSBP-PROD-TAX-GTP_DEMO_CORE-01-39861197"}
		'STG-EUW' {"EY-CTSBP-PROD-TAX-GTP CORE-01-39721502"}
		'PRD-EUW' {"EY-CTSBP-PROD-TAX-GTP CORE-01-39721502"}
		'DEV-USE' {"EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502"}
		'STG-USE' {"EY-CTSBP-PROD-TAX-GTP CORE-01-39721502"}
		'PRD-USE' {"EY-CTSBP-PROD-TAX-GTP CORE-01-39721502"}
	}
	return $subscriptionName;
}
