[CmdletBinding()]
param(
	[Parameter(Mandatory=$True)]
	[ValidateSet('Approved','Scheduled')]
	[string]$Mode,
	[string]$JsonFolderPathname = "..\Pipelines\CTP",
	[string]$vstsAccount = "eyglobaltaxplatform",
	[string]$projectName = "Global%20Tax%20Platform",
	[int]$ReleaseDefinitionId = 155, # alertservice-ctp
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)
Import-Module -Name .\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Verbose: $isVerbose";
$headers =  New-AuthorizationHeader $token;

# Azure DevOps REST APIs for Release Definitions
# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions?view=azure-devops-rest-5.1
$baseUrl = "https://$($vstsAccount).vsrm.visualstudio.com/$($projectName)/_apis";
Write-Output "Base URL is '$baseUrl'";
# Construct the REST URL to obtain release definition
# Definitions - Get
# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/get?view=azure-devops-rest-5.1
$uri = "$($baseUrl)/release/definitions/$($ReleaseDefinitionId)?api-version=5.1"
Write-Output "Invoking GET on '$uri'."
# Invoke the REST call and capture the results
$global:result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $headers
#$result;
# This call should only provide a single result; Capture the Build ID from the result
if ($null -eq $result)
{
     throw "Unable to locate release definition $($ReleaseDefinitionId)"
}
$rdName = $result.name;
Write-Output ("Retrieved $rdName for release definition $ReleaseDefinitionId");
# Get replacement definition
#$jsonPathname = "{0}\{1}-{2}.json" -f $JsonFolderPathname,$rdName,$Mode;
$jsonPathname = "{0}\{1}.json" -f $JsonFolderPathname,$rdName;
Write-Output "Replacing definition details with '$($jsonPathname)'."
$global:newRd = ([string](Get-Content "$jsonPathname") | ConvertFrom-Json );
ForEach ($newEnv in $newRd.Environments)
{
	if ($newEnv.name -ne 'euwqa')
	{
		continue;
	}
	$repEnv = $newEnv;
	Write-Output "Found replacement environment '$($repEnv.name)';"
	Write-Output "Found replacement $($repEnv.schedules.Count) schedules";
	Write-Output "Found replacement $($repEnv.preDeployApprovals.approvals.Count) approver(s)";
}
ForEach ($env in $result.Environments)
{
	if ($env.name -ne 'euwqa')
	{
		continue;
	}
	Write-Output "Found environment '$($env.name)';"
	Write-Output "Found $($env.schedules.Count) schedules";
	$env.schedules = $repEnv.schedules;
	Write-Output "Found $($env.preDeployApprovals.approvals.Count) approver(s)";
	$env.preDeployApprovals.approvals = $rep.preDeployApprovals.approvals;
	
}

# Definitions - Update
# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/update?view=azure-devops-rest-5.1
$global:body = $result | ConvertTo-Json -Compress -Depth 10;
#$body;
#$global:response = Invoke-RestMethod -Uri $uri -Method PUT -ContentType "application/json" -Body $body -Header $header;

