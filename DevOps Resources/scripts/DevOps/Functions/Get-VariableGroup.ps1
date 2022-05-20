Function Get-VariableGroup
{
	<#
	.Synopis
	Get a variable group.

	.Description
	The Get-VariableGroup function gets the content of the -GroupName variable group.

	.Parameter GroupName
	This is the name of an Azure DevOps variable group.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Example
	$variableGroup = Get-VariableGroup 'Next QA Freeze' 'https://dev.azure.com/eyglobaltaxplatform' 'Global Tax Platform' @{authorization = "Basic <<encoded token>>};

	This returns the contents of the 'Next QA Freeze' variable group.

	#>
	[CmdletBinding()]
	param(
		[string]$GroupName,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	# Get existing variable group
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/get%20variable%20groups?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?groupName={groupName}&queryOrder={queryOrder}&api-version=5.1-preview.1
	$variableGroupGet = "_apis/distributedtask/variablegroups?groupName={0}&queryOrder=IdAscending&api-version=5.1-preview" -f $GroupName;
	$uriVariableGroupGet = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$variableGroupGet -join '/'));
	$variableGroupJson = Invoke-RestMethod -Uri $uriVariableGroupGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	if ($null -eq $variableGroupJson)
	{
		Write-Output "Get-VariableGroup '$GroupName' failed."
	}
	$variableGroup = $variableGroupJson.value[0];
	return $variableGroup;
}
