Function Get-AllReleaseDefinitionsByPath
{
	<#
	.Synopsis
	Get all release definitions for the specified path.

	.Description
	The Get-AllReleaseDefinitionsByPath function gets all release definitions for the -Path definition folder path.

	.Parameter Path
	This is the release definition folder full path name (e.g., '\CTP\Release 9.9').

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
	# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?&path={path}&api-version=5.1
	$queryPath = "path={0}" -f $Path;
	$template = "{0}/_apis/release/definitions?{1}&api-version=5.1";
	$uri = $template -f $ProjectUrl,$queryPath;
	return Invoke-RestMethod $uri -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
