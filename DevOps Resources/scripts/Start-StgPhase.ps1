<#
.SYNOPSIS
Update all requested release definitions to start with STG-EUW instead of UAT-DEV.

.DESCRIPTION
This updates all requested release definitions found in -QueryPath to start with STG-EUW instead of UAT-EUW.
This invokes Start-UatStage with the same parameters to handle pipelines cloned during the Staging Phase.

.EXAMPLE
Start-StgPhase -QueryPath @("\CTP\Release 8.4");

This updates the release definitions in the "\CTP\Release 8.4" release pipeline folder.

.Parameter Release
This is the targeted branch for the release definitions of interest.

.PARAMETER QueryPath
This is the path for the release definitions of interest.

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
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release='0.0',
	[Parameter(Mandatory=$false)]
	[string[]]$QueryPaths = @(""),
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Get-Projects()
{
	param(
		[string]$projectName
	)
	Write-Host "Get List of Projects for STG" -ForegroundColor Yellow;
	$foundProject = $false;
	$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
	$projectsUrl = "$($tfsBaseUrl)_apis/projects?api-version=5.1";
	$script:projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header;
	$projects.value |
		Sort-Object -Property name |
		ForEach-Object {
			if ($IsVerbose)
			{
				Write-Host "`t$($_.name)" -ForegroundColor White;
			}
			if ($projectName -eq $_.name)
			{
				$foundProject = $true;
			}
		};
	return $foundProject;
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
if (($Release -eq '0.0') -and (($QueryPaths.Length) -eq 0 -or ($QueryPaths[0] -eq '')))
{
	Stop-ProcessError "Must provide -Release or -QueryPaths parameter";
}
if (($QueryPaths.Length) -eq 1 -and ($QueryPaths[0] -eq ''))
{
	$releasePath = "\CTP\Release {0}" -f $Release;
	$QueryPaths = @($releasePath);
}
Start-UatPhase -QueryPaths $QueryPaths -Account $Account -ProjectName $ProjectName -token $token;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
if (!(Get-Projects($ProjectName)))
{
	throw "'$ProjectName' does not exist in account '$Account'. ";
}
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
foreach ($queryPath in $QueryPaths)
{
	$pathQuery = "path={0}" -f $queryPath;
	$relDefUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?$pathQuery&api-version=5.1";
	$result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header;
	$relDefs = $result.value;
	if ($relDefs.count -gt 0)
	{
		Write-Host "$($ProjectName)$($queryPath) $($relDefs.count) release def founds" -ForegroundColor Yellow;
		$relDefs |
			Sort-Object -Property name |
			ForEach-Object {
				$isChanged = $false;
				$relDefId = $_.id;
				$relDefName = $_.name;
				Write-Host "Reviewing `t$($relDefName)" -ForegroundColor White;
				# get the full definition
				# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions/{definitionId}?api-version=5.1
				$relDefUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions/$($relDefId)?&api-version=5.1";
				$global:relDef = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header;
				# remove properties that don't update
				$relDef.PSObject.Properties.Remove('createdBy')
				$relDef.PSObject.Properties.Remove('createdOn')
				$relDef.PSObject.Properties.Remove('modifiedBy')
				$relDef.PSObject.Properties.Remove('modifiedOn')
				$isChanged = $false;
				# Iterates through all stages
				$relenvs = $relDef.environments;
				foreach ($relEnv in $relEnvs)
				{
					$stageName = $relEnv.name;
					if ($stagename -eq 'UAT-EUW' -and $relEnv.conditions.Count -ne 0)
					{
						$isChanged = $true;
						$relEnv.conditions = @();
					};
					if ($stagename -eq 'STG-EUW')
					{
						$conditions = $relEnv.conditions;
						foreach ($condition in $conditions)
						{
							if ($condition.conditionType -eq 'environmentState')
							{
								$isChanged = $true;
								$condition.name = 'ReleaseStarted';
								$condition.conditionType = 'event';
								$condition.value = "";
							}
						}
					};
				};
				if ($isChanged)
				{
					Write-Host "Updating `t$($relDefName)" -ForegroundColor White;
					# Update the pipeline
					$updateJson = $relDef | ConvertTo-Json -Depth 100 -Compress;
					# PUT https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?api-version=5.1
					$relDefUpdateUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?&api-version=5.1";
					$result = Invoke-RestMethod $relDefUrl -Method Put -ContentType "application/json" -Headers $header -Body $updateJson;
				}
		};
	};
}
