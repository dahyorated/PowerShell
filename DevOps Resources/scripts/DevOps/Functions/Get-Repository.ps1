Function Get-Repository
{
	<#
	.Synopsis
	Get a repository's information.

	.Description
	The Get-Repository function gets the repository information for -RepositoryName.

	.Parameter RepositoryName
	This is the name of an Azure DevOps repository in -TeamProject.

	.Parameter BaseUrl
	This is the base URL for the organization.

	.Parameter TeamProject
	This is the name of the team project.

	.Parameter AuthHeader
	This is a correctly configured basic authentication header.

	.Outputs
	This is the repository information.

	.Example
		$repository = Get-Repository "BoardWalkRepo" "https://dev.azure.com/eyglobaltaxplatform" "Global Tax Platform" @{authorization = "Basic <<encoded token>>};

	This get the information for the 'BoardWalkRepo' repository.
	#>
	[CmdletBinding()]
	param(
		[string]$RepositoryName,
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	# Get existing repository
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories?api-version=5.1
	$repositoryGet = "_apis/git/repositories?api-version=5.1";
	$uriRepositoryGet = [uri]::EscapeUriString(($BaseUrl,$TeamProject,$repositoryGet -join '/'));
	try
	{
		$repositoryJson = Invoke-RestMethod -Uri $uriRepositoryGet -Method Get -ContentType "application/json" -Headers $AuthHeader;
	}
	catch
	{
		$errorMessage = $_.Exception.Message;
		Stop-ProcessError $errorMessage;
	}
	if (($null -eq $repositoryJson) -or ($repositoryJson.count -eq 0))
	{
		$errorMessage = "Get-RepositoryId '$RepositoryName' failed."
		Stop-ProcessError $errorMessage;
	}
	$repository = $repositoryJson.value | Where-Object name -eq $RepositoryName;
	return $repository;
}
