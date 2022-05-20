Function Get-ReleaseDefinitionById
{
	<#
	.Synopis
	Get the release details for a specified release ID.

	.Description
	The Get-ReleaseDefinitionById function gets the release definition details for the -ReleaseDefinitionId release definition ID.

	.Parameter ReleaseDefinitionId
	This is the Azure DevOps identifier for the requested release definition.

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[int]$ReleaseDefinitionId,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/get?view=azure-devops-rest-5.1
	# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions/{definitionId}?api-version=5.1
	$template = "{0}/_apis/release/definitions/{1}?api-version=5.1";
	$relsUrl = $template -f $ProjectUrl,$ReleaseDefinitionId;
	return Invoke-RestMethod $relsUrl -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
