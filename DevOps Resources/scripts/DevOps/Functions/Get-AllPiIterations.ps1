Function Get-AllPiIterations
{
	<#
	.Synopsis
	Get all iterations in the specified PI.

	.Description
	The Get-AllPiIterations function gets all iterations in the PI specified by -SprintNameParts.

	.Parameter SprintNameParts
	This is a string array with four parts:
	- "PI"
	- PI number
	- "Sprint" or "IP"
	- Sprint number or "Sprint"

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter Team
	This is the name of the team.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is an array of all iterations in the PI specified by -SprintNameParts.

	.Example
	$piIterations = Get-AllPiIterations @('PI','9') "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	This sets $piIterations to the information about all iterations in the PI 9.
	#>

	[CmdletBinding()]
	param(
		[string[]]$SprintNameParts,
		[string]$BaseUrl,
		[string]$TeamProject,
		[string]$Team,
		[HashTable]$AuthHeader
	)
	$piMatch = $SprintNameParts[0],$SprintNameParts[1] -join " ";
	# GET https://dev.azure.com/{organization}/{project}/{team}/_apis/work/teamsettings/iterations?api-version=5.1
	$iterationGet = "_apis/work/teamsettings/iterations?api-version=5.1";
	$uriIterationGet = [uri]::EscapeUriString(($BaseUrl,$teamProject,$Team,$iterationGet -join '/'));
	$allIterationsJson = Invoke-RestMethod -Uri $uriIterationGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	$currentPiIterations = $allIterationsJson.value | Where-Object {$_.name.StartsWith($piMatch)};
	return $currentPiIterations;
}
