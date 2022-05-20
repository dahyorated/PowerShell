Function Get-GroupsForOrganization
{
	<#
	.Synopsis
	Get all groups for the EY Global Tax Platform organization.

	.Description
	The Get-GroupsForOrganization script gets all groups for the

	.Parameter AuthHeader
	This is a valid authorization header.
	#>
	[CmdletBinding()]
	param(
		[hashtable]$AuthHeader,
		[Parameter(Mandatory=$false)]
		[string]$Organization = "EYGlobalTaxPlatform"
	)
	# REF https://docs.microsoft.com/en-us/rest/api/azure/devops/graph/groups/list?view=azure-devops-rest-5.1
	# GET https://vssps.dev.azure.com/{organization}/_apis/graph/groups?api-version=5.1-preview.1
	$url = "https://vssps.dev.azure.com/{0}/_apis/graph/groups?api-version=5.1-preview.1" -f $Organization;
	$results = Invoke-RestMethod -Method Get -Uri $url -Headers $AuthHeader;
	return $results;
}
