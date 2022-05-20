Function Remove-VariableGroup
{
	<#
	.Synopis
	Delete a variable group.

	.Description
	The Remove-VariableGroup function deletes the -GroupId variable group.

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
	$variableGroup = Remove-VariableGroup 4 "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	This returns the contents of the variable group with an ID of 4.

	#>
	[CmdletBinding()]
	param(
		[int]$groupId,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	# Delete existing variable group
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/get%20variable%20groups?view=azure-devops-rest-5.1
	# DELETE https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups/{groupId}?api-version=5.1-preview.1
	$variableGroupDelete = "_apis/distributedtask/variablegroups/{0}&api-version=5.1-preview.1" -f $groupId;
	$uriVariableGroupDelete = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$variableGroupDelete -join '/'));
	try
	{
		$variableGroupJson = Invoke-RestMethod -Uri $uriVariableGroupDelete -Method DELETE -ContentType "application/json" -Headers $AuthHeader;
	}
	catch
	{
		Write-Output "Remove-VariableGroup: $($_.Exception.Message)";
		Write-Output "Remove-VariableGroup: $uriVariableGroupDelete";
		Exit 1;
	}
	$variableGroup = $variableGroupJson.value[0];
	return $variableGroup;
}
