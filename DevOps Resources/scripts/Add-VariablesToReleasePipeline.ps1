<#
.Synopsis
Add release-level variables to the requested release pipeline.

.Description
The Add-ReleasePipelineVariableGroups script adds release-level variables to the requested -PipelineName release pipeline.

.Parameter PipelineName
This is the name of the release pipeline.

.Parameter ControlFile
This is the JSON control file that defines the release-level variables.

.Parameter Account
This is the Azure DevOps account.

.Parameter ProjectName
This is the Azure DevOps project to search.

.Parameter Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
Add-ReleasePipelineVariables -PipelineName "mdeservice-db-ctp";

This adds variables to the "mdeservice-db-ctp" release definition.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[string]$PipelineName,
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$ControlFile = "$PSScriptRoot\VariablesRelease.json",
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

Function Add-Variable
{
	param(
		[PSCustomObject]$Def,
		[string]$Name,
		[string]$Value,
		[bool]$AllowOverride
	)
	if ($null -eq $Def.variables.$Name)
	{
		Write-Output ("Adding variable: '{0}' with value '{1}'." -f $Name,$Value);
		$newVar = [PSCustomObject]@{
			value = $Value;
			allowOverride = $AllowOverride;
			};
		$Def.variables | Add-Member -NotePropertyName $Name -NotePropertyValue $newVar;
		$script:added++;
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$control = ConvertFrom-Json -InputObject ([string](Get-Content $ControlFile));
if (($control.name -ne [System.IO.Path]::GetFileNameWithoutExtension($ControlFile)) -or ($control.version -ne 1))
{
	$errorMessage = "Control file '{0}' has incorrect name or version." -f $ControlFile.FullName;
	Stop-ProcessError -ErrorMessage $errorMessage;
}
$reqVars = $control.releaseVariables;
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
			# Iterates through all variables
			$relVars = $relDef.variables;
			foreach ($reqVar in $reqVars)
			{
				$reqVarName = $reqVar.name;
				if ($null -eq $relVars.$reqVarName)
				{
					$reqVarValue = $reqVar.value;
					$reqVarOverride = $reqVar.override;
					Add-Variable -Def $relDef -Name $reqVarName -Value $reqVarValue -AllowOverride $reqVarOverride;
				}
			}
			if ($null -eq $relDef.comment)
			{
				$relDef | Add-Member -NotePropertyName comment -NotePropertyValue "";
			}
			$relDef.comment = "Added {0} variable." -f $added;
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
