Function Get-BoardwalkMainHostPatternFromStageName
{
	<#
	.Synopsis
	Gets the subscription where the app Gateways exist for the specified stage name.

	.Description
	The Get-BoardwalkHostPatternFromStageName function gets the Boardwalk Host Pattern for the -StageName stage name.

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
	$mainHostPattern = $null;
	$mainHostPattern = switch ($StageName)
	{
		'DEV-EUW' {"*{0}d.sbp.eyclienthub.com*"}
		'QAT-EUW' {"*{0}q.sbp.eyclienthub.com*"}
		'UAT-EUW' {"*{0}u.sbp.eyclienthub.com*"}
		'PRF-EUW' {"*{0}f.sbp.eyclienthub.com*"}
		'DMO-EUW' {"*{0}e.sbp.eyclienthub.com*"}
		'STG-EUW' {"*{0}pp.sbp.eyclienthub.com*"}
		'PRD-EUW' {"*{0}p.sbp.eyclienthub.com*"}
		'DEV-USE' {"*{0}d.sbp.eyclienthub.com*"}
		'STG-USE' {"*{0}pp.sbp.eyclienthub.com*"}
		'PRD-USE' {"*{0}p.sbp.eyclienthub.com*"}
	}
	return $mainHostPattern;
}
