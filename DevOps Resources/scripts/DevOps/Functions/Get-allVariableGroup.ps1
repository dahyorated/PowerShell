Function Get-AllVariableGroup
{
	<#
	.Synopis
	Get a set of variable groups.

	.Description
	The Get-AllVariableGroup function gets the set of variable groups that match the -GroupName pattern.

	.Parameter GroupName
	This is the pattern match for a set of Azure DevOps variable groups.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Example
	$variableGroup = Get-VariableGroup '*' 'https://dev.azure.com/eyglobaltaxplatform' 'Global Tax Platform' @{authorization = "Basic <<encoded token>>};

	This returns the set of variable groups that match "*" which is all variable groups.

	#>
	[CmdletBinding()]
	param(
		[string]$GroupName,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	# Get existing variable groups
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/get%20variable%20groups?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?groupName={groupName}&queryOrder={queryOrder}&api-version=5.1-preview.1
	$variableGroupGet = "_apis/distributedtask/variablegroups?groupName={0}&queryOrder=IdAscending&api-version=5.1-preview" -f $GroupName;
	$uriVariableGroupGet = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$variableGroupGet -join '/'));
	$results = Invoke-RestMethod -Uri $uriVariableGroupGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	return $results;
}
