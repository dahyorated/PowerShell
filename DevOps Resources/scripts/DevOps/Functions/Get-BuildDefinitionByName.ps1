Function Get-BuildDefinitionByName
{
	<#
	.Synopis
	Get the build definition details for a specified build definition name.

	.Description
	The Get-BuildDefinitionByName function gets the build definition details for the -BuildDefinitionName build definition ID.

	.Parameter BuildDefinitionName
	This is the Azure DevOps identifier for the requested release definition.

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$BuildDefinitionName,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/list?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions?name={name}&includeAllProperties=true&api-version=5.1
	$template = "{0}/_apis/build/definitions?name={1}&includeAllProperties=true&api-version=5.1";
	$buildDefUrl = $template -f $ProjectUrl,$BuildDefinitionName;
	return Invoke-RestMethod $buildDefUrl -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
