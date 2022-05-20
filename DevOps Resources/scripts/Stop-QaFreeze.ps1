[CmdletBinding()]
param (
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps",
	[Parameter(Mandatory=$False)]
	[string]$WorkItemId = "89645", # Actual work item
	[switch]$WhatIf,
	[switch]$TestWorkItem
)

Function GetUrl() {
	param(
		[string]$orgUrl, 
		[hashtable]$header, 
		[string]$AreaId
	)
	# Build the URL for calling the org-level Resource Areas REST API for the RM APIs
	$orgResourceAreasUrl = [string]::Format("{0}/_apis/resourceAreas/{1}?api-version=5.1-preview", $orgUrl, $AreaId);
	Write-Verbose "orgResourceAreasUrl = '$orgResourceAreasUrl'";
	$results = Invoke-RestMethod -Uri $orgResourceAreasUrl -Headers $header;
	# The "locationUrl" field reflects the correct base URL for the REST API calls
	if ("null" -eq $results) 
	{
		$areaUrl = $orgUrl;
		Write-Verbose "No location URL, using '$orgUrl'";
	}
	else 
	{
		$areaUrl = $results.locationUrl;
		Write-Verbose "Replacing org URL '$orgUrl' with location URL '$areaUrl'.";
	}
	return $areaUrl;
}

Function Get-NonEmptyChoice()
{
	param(
	[string]$envValue,
	[string]$defaultValue)
	Write-Verbose "ENV: '$($envValue)'";
	Write-Verbose "DEF: '$($defaultValue)'";
	if ([string]::IsNullOrWhiteSpace($envValue))
	{
		return $defaultValue;
	}
	else
	{
		return $envValue;
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $ENV:SYSTEM_ACCESSTOKEN;
$tfsBaseUrl = Get-DevOpsUrl -OrgUrl $orgUrl -Header $header -AreaId $coreAreaId;
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Output "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Output "SYSTEM_TEAMPROJECT = '$teamProject'";
if ($TestWorkItem)
{
	$WorkItemId = "92745";
}
Write-Output "Stopping QA freeze."
# Update Work item
# https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items?view=azure-devops-rest-5.1
# PATCH https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?api-version=5.1
# https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_apis/wit/workItems/89645?api-version=5.1
$updatePatch = "_apis/wit/workItems/{0}?api-version=5.1" -f $WorkItemId;
$updatePatchUri = [uri]::EscapeUriString(($tfsBaseUrl,$updatePatch -join '/'));
$contentType = "application/json-patch+json";
$updateBody = @"
[
	{
		"op": "replace",
		"path": "/fields/System.State",
		"value": "Closed"
	},
	{
		"op": "add",
		"path": "/fields/System.History",
		"value": "Stopping QA Freeze"
	}
]
"@;
if ($WhatIf)
{
	Write-Output "Skipping update of '$($WorkItemId)'.";
}
else
{
	Write-Verbose "Invoking update."
	$updateJson = Invoke-RestMethod -Uri $updatePatchUri -Method Patch -ContentType $contentType -Headers $authHeader -Body $updateBody;
	Write-Verbose $updateJson;
}
