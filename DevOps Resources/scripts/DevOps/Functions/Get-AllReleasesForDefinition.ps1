Function Get-AllReleasesForDefinition
{
	<#
	.Synopsis
	Get all releases for a  release definition.

	.Description
	The Get-AllReleasesForDefinition function gets all releases for the specified -releaseDefinitionId;

	.Parameter releaseDefinitionId
	This is the Azure DevOps id for the release definition.

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	.Parameter MaxReleases
	This is the maximum number of releases to retrieve.

	#>
	param(
		[Parameter(Mandatory=$true)]
		[string]$releaseDefinitionId,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader,
		[Parameter(Mandatory=$false)]
		[int]$MaxReleases = 100
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/releases/list?view=azure-devops-rest-5.1
	$template = "{0}/_apis/release/releases?definitionId={1}&`$expand=artifacts&releaseCount={2}&api-version=5.1";
	$uri = $template -f $ProjectUrl,$releaseDefinitionId,$MaxReleases.ToString();
	return Invoke-RestMethod $uri -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
