<#
.Synopsis
Adds variables to a build pipeline.

.Description
The Add-VariableToBuildPipeline script adds the -NewVariables variables to the -PipelineName build pipeline.

.Parameter PipelineName
This is the name of an existing build pipeline.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[string]$PipelineName,
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Get-BuildPipeline
{
	param(
		[string]$PipelineName,
		[string]$ProjectUrl,
		[hashtable]$AuthHeader
	)
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/list?view=azure-devops-rest-5.1
	# GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions?name={name}&path={path}&api-version=5.1
	$uriTemplate = "{0}/_apis/build/definitions?name={1}&api-version=5.1";
	$uri = $uriTemplate -f $projectUrl,$PipelineName;
	return Invoke-RestMethod $uri -Method Get -ContentType "application/json" -Headers $AuthHeader;
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
		Write-Output ("Adding variable: '{0}'." -f $Name);
		$newVar = [PSCustomObject]@{
			value = $Value;
			allowOverride = $AllowOverride;
			};
		$Def.variables | Add-Member -NotePropertyName $Name -NotePropertyValue $newVar;
		$script:addedCount++;
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting Add-VariableToBuildPipeline for '{0}'." -f $PipelineName);
$addedCount = 0;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $buildAreaId;
$projectUrl = "{0}{1}" -f $tfsBaseUrl,$ProjectName;
$results = Get-BuildPipeline -PipelineName $PipelineName -ProjectUrl $projectUrl -AuthHeader $authHeader;
[array]$buildDefs = $results.value;
if ($buildDefs.Count -eq 0)
{
	$errorMessage = "Could not find {0}{1}" -f $SourcePath,$PipelineName;
	Stop-ProcessError -ErrorMessage $errorMessage;
}
$buildId = $buildDefs[0].id;
$buildDef = Get-BuildDefinitionById -BuildDefinitionId $buildId -ProjectUrl $projectUrl -AuthHeader $authHeader;
Add-Variable -Def $buildDef -Name 'varianceThreshold' -Value '80' -AllowOverride $false;
Add-Variable -Def $buildDef -Name 'maxVariance' -Value '1' -AllowOverride $true;
Add-Variable -Def $buildDef -Name 'system.debug' -Value 'false' -AllowOverride $true;
if (($addedCount -gt 0) -and $PSCmdlet.ShouldProcess($PipelineName,"Add Variables"))
{
	Write-Output ("Adding {0} variables to '{1}'," -f $addedCount,$PipelineName);
	$buildDef.PSObject.Properties.Remove('createdBy');
	$buildDef.PSObject.Properties.Remove('createdOn');
	$buildDef.PSObject.Properties.Remove('modifiedBy');
	$buildDef.PSObject.Properties.Remove('modifiedOn');
	$update = Update-BuildDefinitionById -BuildDefinitionId $buildId -BuildDefinition $buildDef -ProjectUrl $projectUrl -AuthHeader $authHeader;
	if ($isVerbose)
	{
		Write-AsJson -CustomObject $update;
	}
}
else
{
	Write-Output ("No updates to '{0}'," -f $PipelineName);
}
Write-Output ("Ending Add-VariableToBuildPipeline for '{0}'." -f $PipelineName);
