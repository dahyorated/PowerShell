Function Update-BuildDefinitionById
{
	<#
	.Synopis
	Update the release definition details for a specified release definition ID.

	.Description
	The Update-BuildDefinitionById function updates the release definition details for the -BuildDefinitionId release definition ID.

	.Parameter BuildDefinitionId
	This is the Azure DevOps identifier for the requested release definition.

	.Parameter BuildDefinition
	This is the updated release definition.

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[int]$BuildDefinitionId,
		[Parameter(Mandatory=$true)]
		[PSCustomObject]$BuildDefinition,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/update?view=azure-devops-rest-5.1
	# PUT https://dev.azure.com/{organization}/{project}/_apis/build/definitions/{definitionId}?api-version=5.1
	$template = "{0}/_apis/build/definitions/{1}?api-version=5.1";
	$relsUrl = $template -f $ProjectUrl,$BuildDefinitionId;
	$updateJson = $BuildDefinition | ConvertTo-Json -Depth 100 -Compress;
	return Invoke-RestMethod $relsUrl -Method PUT -ContentType "application/json" -Body $updateJson -Headers $AuthHeader;
}
