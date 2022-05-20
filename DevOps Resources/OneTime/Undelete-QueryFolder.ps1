<#
.Synopsis
Undelete a shared query or a shared query folder and its contents.

.Description
The Undelete-QueryFolder script undeletes a shared query or a shared query folder and its contents.

.Parameter Pattern
This is the query item or query folder matching pattern.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
	[string]$Pattern = "*infosec*",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Starting Undelete-QueryFolder";
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $witAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
# List URL by Task Id Usage
# https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/list?view=azure-devops-rest-5.1#builddefinitionreference
# GET https://dev.azure.com/{organization}/{project}/_apis/wit/queries?`$includeDeleted=true&api-version=5.1
$uriTemplate = "{0}/_apis/wit/queries?`$depth=2&`$includeDeleted=true&api-version=5.1";
$uri = $uriTemplate -f $projectUrl,$buildVersioningTaskId;
$result = Invoke-RestMethod $uri -Method Get -ContentType "application/json" -Headers $authHeader;
[array]$queries = $result.value;
Write-Output "$($queries.count) query groups found";
$queries |
	Where-Object name -eq 'Shared Queries' | ForEach-Object {
		$_.children | ForEach-Object {
			$queryItem = $_;
			$queryId = $queryItem.id;
			$queryName = $queryItem.name;
			if ($queryName -like $Pattern)
			{
				Write-Output "Found matching query item: '$queryName'.";
				# https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/queries/update?view=azure-devops-rest-5.1#undelete-a-query-or-folder
				# PATCH https://dev.azure.com/fabrikam/Fabrikam-Fiber-Git/_apis/wit/queries/{query}?$undeleteDescendants=true&api-version=5.1
				$queryFullUrl = "$projectUrl/_apis/wit/queries/$($queryId)?`$undeleteDescendants=true&api-version=5.1";
				Write-Output "==>`tUpdating $($queryName)";
				try
				{
					$updateJson = '{"isDeleted": false}';
					$result = Invoke-RestMethod $queryFullUrl -Method Patch -ContentType "application/json" -Headers $authHeader -Body $updateJson;
					if ($result.id -ne $queryId)
					{
						Write-Output "`t==>`Update failed!";
					}
					else
					{
						Write-Output "`t==>`tUpdate succeeded."
					}
				}
				catch
				{
					Write-Output "Update threw exception: $($_.Exception.Message)";
				}
			}; # if ($queryName -like $Pattern)
	}
}
