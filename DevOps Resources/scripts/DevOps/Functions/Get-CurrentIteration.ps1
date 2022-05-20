Function Get-CurrentIteration
{
	<#
	.Synopsis
	Get the current sprint iteration.

	.Description
	The Get-CurrentIteration function gets the current sprint iteration.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter Team
	This is the name of the team.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is the current iteration information.

	Sample JSON output:
	{
		"id":  "4aa07ef2-315f-49ec-a686-c035b9ebf8c0",
		"name":  "PI 9 Sprint 3",
		"path":  "Global Tax Platform\\PI 9\\PI 9 Sprint 3",
		"attributes": 
		{
			"startDate":  "2020-01-27T00:00:00Z",
			"finishDate":  "2020-02-07T00:00:00Z",
			"timeFrame":  "current"
		},
		"url": "https://dev.azure.com/EYGlobalTaxPlatform/c739e34c-9543-4c2c-afaf-889e9c9ac7fb/850470d3-f2e8-4397-bdf5-42fe0fb38450/_apis/work/teamsettings/iterations/4aa07ef2-315f-49ec-a686-c035b9ebf8c0"
	}
	.Example
	$currentIteration = Get-AllCurrentIteration "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	This sets $currentIteration to the information about the current iteration.
	#>

	[CmdletBinding()]
	param(
		[string]$BaseUrl,
		[string]$TeamProject,
		[string]$Team,
		[HashTable]$AuthHeader
	)
	# Get current iteration
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/work/iterations?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/fabrikam/Fabrikam-Fiber/_apis/work/teamsettings/iterations?$timeframe=current&api-version=5.1
	$iterationGet = "_apis/work/teamsettings/iterations?`$timeframe=current&api-version=5.1";
	$uriIterationGet = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$Team,$iterationGet -join '/'));
	$currentIterationJson = Invoke-RestMethod -Uri $uriIterationGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	return $currentIterationJson.value[0];
}
