Function Update-VariableGroup
{
	<#
	.Synopis
	Update a variable group.

	.Description
	The Update-VariableGroup function updates the content of the -GroupId variable group.

	.Parameter Group
	This is an Azure DevOps variable group object.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is the current iteration information.

	.Example
	$UpdatedVariableGroup = Update-VariableGroup <<VGobject>> "{...}" "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" "DevOps" @{authorization = "Basic <<encoded token>>};

	This updates the variable group <<VGobject>>.

	#>
	[CmdletBinding()]
	param(
		[object]$Group,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	$groupId = $Group.id;
	$global:groupJson = $Group | ConvertTo-Json -Depth 100 -Compress;
	# update existing variable group
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/update?view=azure-devops-rest-5.1
	# PUT https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups/{groupId}?api-version=5.1-preview.1
	$variableGroupPut = "_apis/distributedtask/variablegroups/{0}?api-version=5.1-preview.1" -f $groupId;
	$uriVariableGroupPut = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$variableGroupPut -join '/'));
	return Invoke-RestMethod -Uri $uriVariableGroupPut -Method Put -ContentType "application/json" -Headers $AuthHeader -Body $groupJson;
}
