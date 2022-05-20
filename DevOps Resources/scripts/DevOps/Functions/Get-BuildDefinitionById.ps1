Function Get-BuildDefinitionById
{
	<#
	.Synopis
	Get the build definition details for a specified build definition ID.

	.Description
	The Get-ReleaseDefinitionById function gets the build definition details for the -BuildDefinitionId build definition ID.

	.Parameter BuildDefinitionId
	This is the Azure DevOps identifier for the requested release definition.

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
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/get?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions/{definitionId}?api-version=5.1
	$template = "{0}/_apis/build/definitions/{1}?api-version=5.1";
	$buildDefUrl = $template -f $ProjectUrl,$BuildDefinitionId;
	return Invoke-RestMethod $buildDefUrl -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
