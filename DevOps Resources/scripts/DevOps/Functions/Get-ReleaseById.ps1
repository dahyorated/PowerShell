Function Get-ReleaseById
{
	<#
	.Synopis
	Get the release details for a specified release ID.

	.Description
	The Get-ReleaseById function gets the release details for the -ReleaseId release ID.

	.Parameter ReleaseId
	This is the Azure DevOps identifier for the requested release.

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[int]$ReleaseId,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/releases/get%20release?view=azure-devops-rest-5.1
	# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/releases/{releaseId}?api-version=5.1
	$template = "{0}/_apis/release/releases/{1}?api-version=5.1";
	$relsUrl = $template -f $ProjectUrl,$ReleaseId;
	return Invoke-RestMethod $relsUrl -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
