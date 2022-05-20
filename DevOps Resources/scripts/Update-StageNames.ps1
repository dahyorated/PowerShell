<#
 .SYNOPSIS
   Update the stage names of all requested release definitions.

 .DESCRIPTION
   This updates the stage names of all requested release definitions found in -QueryPath.

 .EXAMPLE
   Update-StageNames -QueryPath "\CTP\POC"

   This updates the release definitions in the "\CTP\POC" release pipeline folder. 

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
	[string[]]$QueryPaths = @("\CTP\POC\BMF"),
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
	Write-Host "Get List of Projects" -ForegroundColor Yellow;
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

Function ConvertStageName{
	param(
		[string]$stageName
	)
	switch ($stageName)
	{
		'euwdev'{ return 'DEV-EUW';}
		'euwqa' { return  'QAT-EUW';}
		'usedev' { return 'DEV-USE';}
		'euwuat' { return 'UAT-EUW';}
		'euwperf' { return 'PRF-EUW';}
		'euwstage' { return 'STG-EUW';}
		'euwprod' { return 'PRD-EUW';}
		'usestage' { return 'STG-USE';}
		'useprod' { return 'PRD-USE';}
		default { return $stageName; } 
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
# Define all area IDs
# https://docs.microsoft.com/en-us/azure/devops/extend/develop/work-with-urls?view=azure-devops&tabs=http&viewFallbackFrom=vsts#resource-area-ids-reference
$coreAreaId = "79134c72-4a58-4b42-976c-04e7115f32bf";
$releaseManagementAreaId = "efc2f575-36ef-48e9-b672-0c6fb4a48ac5";

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
				$relDef.PSObject.Properties.Remove('createdBy');
				$relDef.PSObject.Properties.Remove('createdOn');
				$relDef.PSObject.Properties.Remove('modifiedBy');
				$relDef.PSObject.Properties.Remove('modifiedOn');
				$isChanged = $false;
				# Iterates through all stages
				$relenvs = $relDef.environments;
				foreach ($relEnv in $relEnvs)
				{
					$oldStageName = $relEnv.name;
					$newStageName = ConvertStageName $oldStageName;
					if ($newStageName -ne $oldStageName)
					{
						$isChanged = $true;
						$relEnv.name = $newStageName;
					}
					$conditions = $relEnv.conditions;
					foreach ($condition in $conditions)
					{
						if ($condition.conditionType -eq 'environmentState')
						{
							$oldStageName = $condition.name;
							$newStageName = ConvertStageName $oldStageName;
							if ($newStageName -ne $oldStageName)
							{
								$isChanged = $true;
								$condition.name = $newStageName;
							}						}
					}
				}
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
