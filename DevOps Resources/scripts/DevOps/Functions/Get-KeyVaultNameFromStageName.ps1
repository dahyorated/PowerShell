Function Get-KeyVaultNameFromStageName
{
	<#
	.Synopsis
	Gets the key vault name for the specified stage name.

	.Description
	The Get-KeyVaultNameFromStageName function gets the key vault name for the -StageName stage name.

	.Parameter StageName
	This is a DevOps standard stage name. If not specified, it defaults to the current release stage name (i.e., $ENV:RELEASE_ENVIRONMENTNAME).
	#>
	param(
		[Parameter(Mandatory=$false)]
		[ValidatePattern('(DEV|QAT|UAT|DMO|PRF|STG|PRD)-(EUW|USE)')]
		[string]$StageName = $ENV:RELEASE_ENVIRONMENTNAME
	)
	if ([string]::IsNullOrWhiteSpace($StageName))
	{
		$message = "No value was provided for [RELEASE_ENVIRONMENTNAME]";
		Stop-ProcessError $message;
	}
	$keyVaultName = switch ($StageName)
	{
		'DEV-EUW' {"EUWDGTP005AKV01"}
		'QAT-EUW' {"EUWQGTP007AKV01"}
		'UAT-EUW' {"EUWUGTP014AKV01"}
		'PRF-EUW' {"EUWFGTP012AKV01"}
		'DMO-EUW' {"EUWEGTP035AKV09"}
		'STG-EUW' {"EUWXGTP020AKV01"}
		'PRD-EUW' {"EUWPGTP018AKV04"}
		'DEV-USE' {"USEDGTP004AKV01"}
		'STG-USE' {"USEXGTP021AKV01"}
		'PRD-USE' {"USEPGTP019AKV04"}
	}
	return $keyVaultName;
}
