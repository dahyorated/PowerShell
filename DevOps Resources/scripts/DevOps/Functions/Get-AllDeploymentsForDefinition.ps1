Function Get-AllDeploymentsForDefinition
{
	<#
	.Synopsis
	Get all releases for a  release definition.

	.Description
	The Get-AllDeploymentsForDefinition function gets all deployments for the specified -releaseDefinitionId;

	.Parameter ReleaseDefinitionId
	This is the Azure DevOps id for the release definition.

	.Parameter ProjectUrl
	This is the URI for the Azure DevOps project.

	.Parameter AuthHeader
	This is a valid authorization header.

	.Parameter MaxDeployments
	This is the maximum number of deployments to retrieve.

	#>
	param(
		[Parameter(Mandatory=$true)]
		[string]$ReleaseDefinitionId,
		[Parameter(Mandatory=$true)]
		[string]$ProjectUrl,
		[Parameter(Mandatory=$true)]
		[Hashtable]$AuthHeader,
		[Parameter(Mandatory=$false)]
		[int]$MaxDeployments = 100
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/deployments/list?view=azure-devops-rest-5.1
	# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/deployments?definitionId={definitionId}&deploymentStatus={deploymentStatus}&operationStatus={operationStatus}&$top={$top}&api-version=5.1
	$template = "{0}/_apis/release/deployments?definitionId={1}&deploymentStatus=all&operationStatus=all&`$top={2}&api-version=5.1";
	$relUrl = $template -f $ProjectUrl,$ReleaseDefinitionId,$MaxDeployments.ToString();
	return Invoke-RestMethod $relUrl -Method Get -ContentType "application/json" -Headers $AuthHeader;
}
