Function Get-DevOpsUrl
{
	<#
	.Synopsis
	Get the URL for calling the organization-level Resource Areas REST APIs.

	.Description
	The Get-DevOpsUrl function gets the URL for calling the -OrgUrl organization-level Resource Areas REST APIs.

	.Parameter OrgUrl
	This is the organization URL that includes the account name.

	.Parameter Header
	This is the authentication header.

	.Parameter AreaId
	This is the resource area for which the vvalid URL is obtained.
#>
	[CmdletBinding()]
	param(
		[string]$OrgUrl,
		[hashtable]$Header,
		[string]$AreaId
	)
	$orgResourceAreasUrl = [string]::Format("{0}/_apis/resourceAreas/{1}?api-version=5.1-preview", $OrgUrl, $AreaId);
	$results = Invoke-RestMethod -Uri $orgResourceAreasUrl -Headers $Header;
	# The "locationUrl" field reflects the correct base URL for the REST API calls
	if ("null" -eq $results)
	{
		$areaUrl = $OrgUrl;
	}
	else
	{
		$areaUrl = $results.locationUrl;
	}
	return $areaUrl;
}
