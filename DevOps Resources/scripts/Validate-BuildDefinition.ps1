<#
.Synopsis
Validate that a build pipeline definition is ready for DevOps automation.

.Description
The Validate-BuildDefinition script validates that the -PipelineName build pipeline definition is ready for DevOps automation.

.PARAMETER PipelineName
This is the name of the pipeline to validate.

.Parameter ValidationControl
This is the JSON file that contains validation controls.

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
	[Parameter(Mandatory=$true,ValueFromPipeline)]
	[string]$PipelineName,
	[Parameter(Mandatory=$false)]
	[string]$ValidationControl = "$PSScriptRoot\ValidationControlBuildDefinitions.json",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Test-GlobalBuildVariableUsage
{
	param(
	[PSCustomObject]$BuildVariable,
	[PSCustomObject]$BuildDefinition
	)
	$varName = $BuildVariable.name;
	$expectedValue = $BuildVariable.value;
	$varPattern = $BuildVariable.valuePattern;
	$allowOverride = $BuildVariable.allowOverride;
	$isRequired = $BuildVariable.isRequired;
	$varType = $BuildVariable.bldType;
	$isVarGroup = $BuildVariable.isVarGroup;
	$checkUsage = $BuildVariable.checkUsage;
	if (($varType -ne $bldTypeAll) -and ($varType -ne $script:bldDefType))
	{
		return;
	}
	if ($isVarGroup)
	{
		$varGroup = $BuildDefinition.variableGroups | Where-Object name -eq $varName;
		if ($null -eq $varGroup)
		{
			Write-Output ("==> {0}: Missing required variable group." -f $varName);
			$script:errorCount++;
		}
		return;
	}
	$bldVar = $BuildDefinition.variables.$varName;
	if ($isRequired -and ($null -eq $bldVar) -and (($varType -eq $bldTypeAll) -or ($varType -eq $script:bldDefType)))
	{
		Write-Output ("==> {0}: Missing required variable." -f $varName);
		$script:errorCount++;
		return;
	}
	if (-not $isRequired -and ($null -eq $bldVar))
	{
		return;
	}
	$varAllowOverride = $bldVar.allowOverride;
	if ($allowOverride)
	{
		if (($null -eq $varAllowOverride) -or (-not $varAllowOverride))
		{
			Write-Output ("==> {0}: Must allow override." -f $varName);
			$script:errorCount++;
		}
	}
	else
	{
		if (($null -ne $varAllowOverride) -and ($varAllowOverride))
		{
			Write-Output ("==> {0}: Must not allow override." -f $varName);
			$script:errorCount++;
		}
	}
	$varValue = $bldVar.value;
	if ($null -ne $varPattern)
	{
		$match = $varValue -match $varPattern;
		if (-not $match)
		{
			Write-Output ("==> {0}: Does not match pattern '{1}'." -f $varName,$varPattern);
			$script:errorCount++;
		}
	}
	if ($null -ne $expectedValue)
	{
		if ($expectedValue -ne $varValue)
		{
			Write-Output ("==> {0}: Has value '{1}', required value '{2}'." -f $varName,$varValue,$expectedValue);
			$script:errorCount++;
		}
	}
	if ($checkUsage)
	{
		$isMissing = $true;
		$bldPhases = $BuildDefinition.process.phases;
		$correctUsage = "`$({0})" -f $varName;
		foreach ($bldPhase in $bldPhases)
		{
			$phaseName = $bldPhase.name;
			[array]$steps = $bldPhase.steps;
			foreach ($step in $steps)
			{
				$stepName = $step.displayName;
				if ($null -ne $step.inputs.$varName)
				{
					$isMissing = $false;
					if ($step.inputs.$varName -ne $correctUsage)
					{
						Write-Output ("==> Processing phase '{0}', step {1}." -f $phaseName,$stepName);
						Write-Output ("==> {0}: Has incorrect value '{1}'." -f $varName,$step.inputs.maxVariance.value);
						$script:errorCount++;
					}
					else
					{
						Write-Verbose "==> maxVariance is correct.";
					}
				}
			}
		}
		if ($isMissing)
		{
			Write-Output ("==> {0}: Is never referenced as '{1}'." -f $varName,$correctUsage);
			$script:errorCount++;
		}
	}
}


Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
# Constants
$bldTypeAll = "ALL";
$bldTypeSvc = "SVC";
$bldTypeDb = "DB";
Write-Output ("Validating '{0}'." -f $PipelineName);
$errorCount = 0;
$control = Get-Content $ValidationControl | ConvertFrom-Json;
$buildVariables = $control.globalValidations.buildVariables;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $buildAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$results = Get-BuildDefinitionByName -BuildDefinitionName $PipelineName -ProjectUrl $projectUrl -AuthHeader $header;
if ($results.Count -eq 0)
{
	$errorMessage = "Could not find '{0}'." -f $PipelineName;
	Stop-ProcessError -ErrorMessage $errorMessage;
}
$bldDef = $results.value[0];
if (($PipelineName -like '*database*') -or ($PipelineName -like '*datawarehouse*'))
{
	$bldDefType = $bldTypeDb;
}
else
{
	$bldDefType = $bldTypeSvc;
}
$triggers = $bldDef.triggers;
[array]$branchFilters = $triggers.branchFilters;
$branchFiltersCount = $branchFilters.Count;
$expectedBranchFilter = "+refs/heads/develop";
switch ($branchFiltersCount)
{
	0
	{
		Write-Output "==> Missing branch filter.";
		$errorCount++;
	}
	1
	{
		$filter = $branchFilters[0];
		if ($filter -ne $expectedBranchFilter)
		{
			Write-Output ("==> Branch filter is '{0}'; expected {1}." -f $filter,$expectedBranchFilter);
			$errorCount++;
		}
	}
	default
	{
		Write-Output ("==> Has {0} branch filters; expected 1." -f $branchFiltersCount);
		$errorCount++;
	}
}
foreach ($bldVar in $buildVariables)
{
	Test-GlobalBuildVariableUsage -BuildVariable $bldVar -BuildDefinition $bldDef;
}
if ($errorCount -ne 0)
{
	Write-Output ("==> Found {0} validation errors in '{1}'." -f $errorCount,$PipelineName);
}
else
{
	Write-Output ("==> {0}: No validation errors." -f $PipelineName);
}
