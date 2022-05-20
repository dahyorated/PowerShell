Function New-VariableGroup
{
	<#
	.Synopis
	Add a variable group.

	.Description
	The New-VariableGroup function adds the content of -VariableGroup as a new variable group.

	.Parameter VariableGroup
	This is an Azure DevOps variable group object.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is the new variable group information.

	.Example
	$addedVariableGroup = New-VariableGroup <<VGobject>> "{...}" "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	This adds the variable group <<VGobject>>.

	#>
	[CmdletBinding()]
	param(
		[object]$VariableGroup,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	$groupJson = $VariableGroup | ConvertTo-Json -Depth 100 -Compress;
	# add a new variable group
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/update?view=azure-devops-rest-5.1
	# POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=5.1-preview.1
	$variableGroupAdd = "_apis/distributedtask/variablegroups?api-version=5.1-preview.1";
	$uriVariableGroupAdd = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$variableGroupAdd -join '/'));
	return Invoke-RestMethod -Uri $uriVariableGroupAdd -Method Post -ContentType "application/json" -Headers $AuthHeader -Body $groupJson;
}
