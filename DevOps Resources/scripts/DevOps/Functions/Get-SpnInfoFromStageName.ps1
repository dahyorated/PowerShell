Function Get-SpnInfoFromStageName
{
	<#
	.Synopsis
	Get the SPN ID and password based on a stage name.

	.Description
	The Get-SpnInfoFromStageName function gets the SPN ID and password based on the -StageName stage name.

	.Parameter StageName
	This is a DevOps standard stage name.

	.Parameter UseCore
	If specified, this gets the Core SPN. Otherwise, it gets the tenant SPN.

	.Outputs
	The output is a [PsCustomObject] that contains three variables.
	- SpnId: The application ID for the SPN.
	- SpnName: The display name for the SPN.
	- SpnPassword: The password for the SPN.

	.Example
	Get-SpnInfoFromStageName -StageName 'DEV-EUW';

	This returns a tuple containing the SPN name, application id, and secret for the 'DEV-EUW' environment.
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$StageName,
		[switch]$UseCore
	)
	try
	{
		$keyVaultName = Get-KeyVaultNameFromStageName -StageName $StageName;
		$applicationId = Get-ApplicationIdFromStageName -StageName $StageName -UseCore:$UseCore;
		$spn = Get-AzADServicePrincipal -ApplicationId $applicationId;
		$spnName = $spn.DisplayName;
		$secretName = "SPNKey-{0}" -f $spnName.Replace("_","-");
		$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName;
		$password = $secret.SecretValueText;
	}
	catch
	{
		$message = "Get-SpnInfoFromStageName Failed: {0}" -f $_.Exception.Message;
		Stop-ProcessError -errorMessage $message;
	}
	return [PSCustomObject]@{
		SpnName = $spnName;
		SpnId = $applicationId;
		SpnPassword = $password;
	}
}
