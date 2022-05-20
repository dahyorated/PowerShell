Function Get-VariableGroupById
{
	<#
	.Synopis
	Get a variable group.

	.Description
	The Get-VariableGroupById function gets the content of the -GroupId variable group.

	.Parameter GroupId
	This is the ID of an Azure DevOps variable group.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is the current iteration information.

	.Example
	$variableGroup = Get-VariableGroupById 4 "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	This returns the contents of the variable group with an ID of 4.

	#>
	[CmdletBinding()]
	param(
		[int]$groupId,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	# Get existing variable group
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/get%20variable%20groups?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups/{groupId}?api-version=5.1-preview.1
	$variableGroupGet = "_apis/distributedtask/variablegroups?groupIds={0}&api-version=5.1-preview.1" -f $groupId;
	$uriVariableGroupGet = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$variableGroupGet -join '/'));
	try
	{
		$variableGroupJson = Invoke-RestMethod -Uri $uriVariableGroupGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	}
	catch
	{
		Write-Output "Get-VariableGroupById: $($_.Exception.Message)";
		Write-Output "Get-VariableGroupById: $uriVariableGroupGet";
		Exit 1;
	}
	return $variableGroupJson.value[0];
}
