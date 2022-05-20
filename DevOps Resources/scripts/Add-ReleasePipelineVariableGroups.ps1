<#
.Synopsis
Add variable groups to all stages of the requested release pipeline.

.Description
The Add-ReleasePipelineVariableGroups script adds the -Set variable groups to all stages of the -PipelineName release pipeline.

.Parameter PipelineName
This is the name of the release pipeline.

.Parameter Set
This is the set of variable groups to add. Options are:
- All: Add all defined variable groups.
- Iac: Add the 'iacvariables-*' variable groups.
- Service: Add the 'serviceurls-*' variable groups.

.Parameter ControlFile
This is the JSON control file that defines the variable groups by stage for each allowed -Set.

.Parameter Account
This is the Azure DevOps account.

.Parameter ProjectName
This is the Azure DevOps project to search.

.Parameter Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
Add-ReleasePipelineVariableGroups -PipelineName "mdeservice-db-ctp";

This adds the 'Iac' variable groups to the "mdeservice-db-ctp" release definitions.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[string]$PipelineName,
	[Parameter(Mandatory=$false)]
	[ValidateSet('All','Iac','Service')]
	[string]$Set = 'All',
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$ControlFile = "$PSScriptRoot\VariableGroupSetsRelease.json",
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
	Write-Output "Get List of Projects";
	$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
	$projectsUrl = "$($tfsBaseUrl)_apis/projects?api-version=5.1";
	$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header;
	return ($null -ne ($projects.value | Where-Object name -eq $projectName));
}

Function Get-VariableGroupId
{
	param(
		[string]$stageName,
		[string]$setName,
		[PSCustomObject]$control
	)
	$set = $control.sets | Where-Object name -eq $setName;
	$group = $set.groups |Where-Object stage -eq $stageName;
	return $group.id;
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
if ($Set -eq 'All')
{
	$sets = @('Iac','Service');
}
else
{
	$sets = @($Set);
}
$control = ConvertFrom-Json -InputObject ([string](Get-Content $ControlFile));
if (($control.name -ne [System.IO.Path]::GetFileNameWithoutExtension($ControlFile)) -or ($control.version -ne 1))
{
	$errorMessage = "Control file '{0}' has incorrect name or version." -f $ControlFile.FullName;
	Stop-ProcessError -ErrorMessage $errorMessage;
}
if (!(Get-Projects($ProjectName)))
{
	$errorMessage = "'$ProjectName' does not exist in account '$Account'. ";
	Stop-ProcessError -ErrorMessage $errorMessage;
}
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1
$searchText = "searchText={0}&isExactNameMatch=true" -f $PipelineName;
$relDefUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?$searchText&api-version=5.1";
$result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header;
$relDefs = $result.value;
if ($relDefs.count -gt 0)
{
	Write-Output "$($ProjectName):$($PipelineName) $($relDefs.count) release def founds";
	$relDefs |
		Sort-Object -Property name |
		ForEach-Object {
			$isChanged = $false;
			$relDefId = $_.id;
			$relDefName = $_.name;
			Write-Host ("==> Reviewing '{0}'." -f $relDefName);
			# get the full definition
			# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions/{definitionId}?api-version=5.1
			$relDefUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions/$($relDefId)?&api-version=5.1";
			$global:relDef = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header;

			# remove properties that don't update
			$relDef.PSObject.Properties.Remove('createdBy')
			$relDef.PSObject.Properties.Remove('createdOn')
			$relDef.PSObject.Properties.Remove('modifiedBy')
			$relDef.PSObject.Properties.Remove('modifiedOn')
			$added =0;
			# Iterates through all stages
			$relenvs = $relDef.environments;
			foreach ($relEnv in $relEnvs)
			{
				$stageName = $relEnv.name;
				foreach ($setName in $sets)
				{
					$vg = Get-VariableGroupId -control $control -setName $setName -stageName $stageName;
					if ($vg -ne 0)
					{
						[System.Collections.ArrayList]$allVariableGroups = $relEnv.variableGroups;
						if (($null -eq $allVariableGroups) -or ($allVariableGroups.Count -eq 0))
						{
							$added++;
							$relEnv.variableGroups = @($vg);
						}
						elseif (-not ($relEnv.variableGroups -contains $vg))
						{
							$added++;
							$newIndex = $allVariableGroups.Add($vg);
							Write-Verbose ("Added `$allVariableGroups[{0}]." -f $newIndex);
							$relEnv.variableGroups = $allVariableGroups;
						}
					}
				}
			}
			if ($null -eq $relDef.comment)
			{
				$relDef | Add-Member -NotePropertyName comment -NotePropertyValue "";
			}
			$relDef.comment = "Added {0} variable groups from set '{1}'." -f $added,$Set;
			if (($added -gt 0) -and $PSCmdlet.ShouldProcess($PipelineName,"Add variable Groups"))
			{
				Write-Output ("==> Updating '{0}'" -f $relDefName);
				Write-Output ("==> {0}" -f $relDef.comment);
				# Update the pipeline
				$updateJson = $relDef | ConvertTo-Json -Depth 100 -Compress;
				Write-Verbose $updateJson;
				# PUT https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?api-version=5.1
				$relDefUpdateUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?&api-version=5.1";
				$result = Invoke-RestMethod $relDefUrl -Method Put -ContentType "application/json" -Headers $header -Body $updateJson;
			}
			else
			{
				Write-Output "==> No changes.";
			}
	};
};
