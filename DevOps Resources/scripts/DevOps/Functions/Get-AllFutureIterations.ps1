Function Get-AllFutureIterations
{
	<#
	.Synopsis
	Get all future iterations in the specified PI.

	.Description
	The Get-AllFutureIterations function gets all future iterations.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter Team
	This is the name of the team.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is an array of all future iterations.

	.Example
	$futureIterations = Get-AllFutureIterations "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	#>
	[CmdletBinding()]
	param(
		[string]$BaseUrl,
		[string]$TeamProject,
		[string]$Team,
		[HashTable]$AuthHeader
	)
	# GET https://dev.azure.com/{organization}/{project}/{team}/_apis/work/teamsettings/iterations?api-version=5.1
	$iterationGet = "_apis/work/teamsettings/iterations?api-version=5.1";
	$uriIterationGet = [uri]::EscapeUriString(($BaseUrl,$teamProject,$Team,$iterationGet -join '/'));
	$allIterationsJson = Invoke-RestMethod -Uri $uriIterationGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	$futureIterations = $allIterationsJson.value | Where-Object {$_.attributes.timeframe -eq 'future'};
	return $futureIterations;
}
