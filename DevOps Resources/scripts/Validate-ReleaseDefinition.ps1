<#
.Synopsis
Validate that a release pipeline definition is ready for DevOps automation.

.Description
The Validate-ReleaseDefinition script validates that the -PipelineName release pipeline definition is ready for DevOps automation.

.PARAMETER PipelineName
This is the name of the pipeline to validate.

.PARAMETER SourcePath
This is the source path and must include the leading "\".

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
	[string]$SourcePath = "\CTP",
	[Parameter(Mandatory=$false)]
	[string]$ValidationControl = "$PSScriptRoot\ValidationControlReleaseDefinitions.json",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Test-VariableIsDefined
{
	param(
		[Parameter(Mandatory=$true)]
		[string]$variableName,
		[Parameter(Mandatory=$false)]
		[string]$variableValue
	)
	$variable = $variables.$variableName;
	if ($null -eq $variable)
	{
		Write-Output ("==> Pipeline variable '{0}' is missing." -f $variableName);
		$script:errorCount++;
	}
	elseif ([string]::IsNullOrWhiteSpace($variable.value))
	{
		Write-Output ("==> Pipeline variable '{0}' has no value." -f $variableName);
		$script:errorCount++;
	}
	elseif ((-not [string]::IsNullOrWhiteSpace($variableValue)) -and ($variableValue -ne $variable.value))
	{
		Write-Output ("==> Pipeline variable '{0}' has value '{1}' instead of '{2}'." -f $variableName,$variable.value,$variableValue);
		$script:errorCount++;
	}
}

Function Test-GlobalStageVariableUsage
{
	param(
	[PSCustomObject]$StageVar,
	[PSCustomObject]$Stage
	)
	$varName = $StageVar.name;
	$relVar = $script:relDef.variables.$varName;
	if (($null -ne $relVar) -and ($relVar.value -ne 'NA'))
	{
		continue;
	}
	$varType = $StageVar.relType;
	$reqVarAlias = $StageVar.aliases;
	$relStageVar = $stage.variables.$varName;
	$varGroup = $StageVar.varGroup;
	if ((-not $varGroup) -and ($null -eq $relStageVar) -and (($varType -eq $relTypeAll) -or ($varType -eq $script:relDefType)))
	{
		Write-Output ("==> {0}: Missing required variable '{1}'." -f $stageName,$varName);
		$script:errorCount++;
	}
	$expectedValue = "`$({0})" -f $varName;
	foreach ($phase in $relStage.deployPhases)
	{
		$phaseName = $phase.name;
		foreach ($task in $phase.workflowTasks)
		{
			$taskName = $task.name;
			$actualValue = "";
			if ($null -ne $task.inputs.$varName)
			{
				$actualValue = $task.inputs.$varName;
			}
			else
			{
				foreach ($alias in $reqVarAlias)
				{
					if ($null -ne $task.inputs.$alias)
					{
						$actualValue = $task.inputs.$alias;
					}
				}
			};
			if ((-not [string]::IsNullOrEmpty($actualValue)) -and $expectedValue -ne $actualValue)
			{
				Write-Output ("==> {0}: Required variable '{1}' set to hard-coded value '{2}' in '{3}/{4}." -f $stageName,$varName,$actualValue,$phaseName,$taskName);
				$script:errorCount++;
			}
		}
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Validating '{0}\{1}'." -f $SourcePath,$PipelineName);
$control = Get-Content $ValidationControl | ConvertFrom-Json;
$releaseVariables = $control.globalValidations.releaseVariables;
$allStagesVariables = $control.globalValidations.stageVariables;
$badPrimaryArtifacts = $control.globalValidations.badPrimaryArtifacts;
$minDbStages = 7;
$minSvcStages = 10;
$relTypeAll = "ALL";
$relTypeSvc = "SVC";
$relTypeDb = "DB";
if ($PipelineName -notlike '*-ctp')
{
	Write-Output "Pipeline definition must end with '-ctp'.";
}
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$groupsResult =Get-GroupsForOrganization -AuthHeader $header;
[array]$groups =$groupsResult.value | Where-Object principalName -like '*Release*';
$isDatabasePipeline = $PipelineName -like '*-db-*';
if ($isDatabasePipeline)
{
	$relDefType = $relTypeDb;
}
else
{
	$relDefType = $relTypeSvc;
}
# Retrieve release pipeline definition
$result = Get-AllReleaseDefinitionsByPath -Path $SourcePath -ProjectUrl $projectUrl -AuthHeader $authHeader;
[array]$relDefs = $result.value;
if ($relDefs.Count -eq 0)
{
	Write-Output ("There are no pipelines in the '{0}' folder." -f $SourcePath);
	Exit;
}
$relDefBrief = $relDefs | Where-Object name -eq $PipelineName;
if ($null -eq $relDefBrief)
{
	Write-Output ("==> Pipeline '{0}' was not in '{1}' folder." -f $PipelineName,$SourcePath);
	Exit;
}
$relDefId = $relDefBrief.id;
$relDef = Get-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $authHeader;
if ($null -eq $relDef)
{
	Write-Output ("==> Could not retrieve '{0}' definition details." -f $PipelineName);
	Exit;
}
$errorCount = 0;
Write-Verbose "==> Artifact validation";
[array]$artifacts = $relDef.artifacts;
if ($artifacts.Count -eq 0)
{
	Write-Output "==> There are no artifacts.";
	$errorCount++;
}
else
{
	[array]$primaryArtifact = $artifacts | Where-Object isPrimary -eq "true";
	$artifactCount = $artifacts.Count;
	if ($primaryArtifact.Count -eq 0)
	{
		Write-Output "==> There is no primary artifact.";
		$errorCount++;
	}
	else
	{
		$buildName = $primaryArtifact[0].definitionReference.definition.name;
		if (($badPrimaryArtifacts -contains $buildName) -and ($artifactCount -ne 1))
		{
			Write-Output ("==> '{0}' is not allowed as the primary artifact." -f $buildName);
			$errorCount++;
		}
		else
		{
			Write-Output ("==> Primary artifact is '{0}'." -f $buildName);
		}
	}
}
Write-Verbose "==> Trigger validation";
[array]$environments = $relDef.environments;
$variables = $relDef.variables;
$triggers = $relDef.triggers;
$trigger = $triggers | Where-Object{$_.triggerType -eq 'artifactSource'};
if ($null -eq $trigger)
{
	Write-Output "==> Continuous deployment trigger is disabled.";
	$errorCount++;
}
else
{
	$triggerCondition = $trigger.triggerConditions | Where-Object {$_.sourceBranch -eq 'develop'};
	if ($null -eq $triggerCondition)
	{
		Write-Output "==> Continuous deployment trigger is not filtered by 'develop'";
		$errorCount++;
	}
	else
	{
		$triggerCondition.sourceBranch = $releaseBranch;
	}
}
$stageCount = 0;
Write-Verbose "==> Stage validations";
$environments |
	Sort-Object name |
	ForEach-Object {
		$relStage = $_;
		$stageCount++;
		$stageName = $relStage.name.Trim();
		Write-Verbose ("==> Stage '{0}' validation" -f $stageName);
		if ($stageName -ne $relStage.name)
		{
			Write-Output ("==> Stage name '{0}' contains spaces." -f $relStage.name);
			$errorCount++;
		};
		$preDeploymentGates = $relStage.preDeploymentGates;
		$gatesOptions = $preDeploymentGates.gatesOptions;
		$gates = $preDeploymentGates.gates;
		[array]$matchingStage = $control.stageVariables | Where-Object stageName -eq $stageName;
		if ($matchingStage.Count -eq 0)
		{
			Write-Output ("==> '{0}' is not an acceptable stage name." -f $stageName);
			$errorCount++;
		}
		switch ($stageName)
		{
			'QAT-EUW'
			{
				if (($null -eq $gatesOptions) -or (-not $gatesOptions.isEnabled))
				{
					Write-Output ("==> Stage name '{0}' does not have pre-deployment gates enabled." -f $relStage.name);
					$errorCount++;
				}
				else
				{
					if ($gatesOptions.samplingInterval -ne 30)
					{
						Write-Output ("==> Stage name '{0}' sampling interval of {1} should be 30 minutes." -f $relStage.name,$gatesOptions.samplingInterval);
					$errorCount++;
					}
					if ($gatesOptions.timeout -ne 21600) # 15 days
					{
						Write-Output ("==> Stage name '{0}' timeout of {1} should be 15 days (21600 minutes)." -f $relStage.name,$gatesOptions.samplingInterval);
					$errorCount++;
					}
					if ($gatesOptions.minimumSuccessDuration -ne 0)
					{
						Write-Output ("==> Stage name '{0}' minimum success duration of {1} should be 0 minutes." -f $relStage.name,$gatesOptions.samplingInterval);
					$errorCount++;
					}
				}
				if ($gates.Count -eq 0)
				{
					Write-Output ("==> Stage name '{0}' does not have any gates defined." -f $relStage.name);
					$errorCount++;
				}
				elseif ($gates.Count -gt 1)
				{
					Write-Output ("==> Stage name '{0}' has {1} gates defined; expected 1." -f $relStage.name,$gates.Count);
					$errorCount++;
				}
				elseif ($gates[0].tasks.Count -ne 1)
				{
					Write-Output ("==> Stage name '{0}' has {1} gate tasks defined; expected 1." -f $relStage.name,$gates[0].tasks.Count);
					$errorCount++;
				}
				else
				{
					if ($gates[0].tasks[0].inputs.queryId -ne '4143a0c2-85b1-42dd-963b-66e0e8e04aa4')
					{
						Write-Output ("==> Stage name '{0}' has incorrect gates query defined." -f $relStage.name);
						$errorCount++;
					}
					if ($gates[0].tasks[0].inputs.maxThreshold -ne 1)
					{
						Write-Output ("==> Stage name '{0}' has incorrect Maximum Threshold of {1}, must be 1." -f $relStage.name,$gates[0].tasks[0].inputs.maxThreshold);
						$errorCount++;
					}
					if ($gates[0].tasks[0].inputs.minThreshold -ne 1)
					{
						Write-Output ("==> Stage name '{0}' has incorrect Minimum Threshold of {1}, must be 1." -f $relStage.name,$gates[0].tasks[0].inputs.minThreshold);
						$errorCount++;
					}
				}
			}
			default
			{
				if ($null -ne $gatesOptions -and $gatesOptions.isEnabled)
				{
					$errorCount++;
					Write-Output ("==> Stage name '{0}' has pre-deployment gates enabled." -f $relStage.name);
				}
			}
		};
		Write-Verbose "==> Check global stage variables";
		foreach ($reqVar in $allStagesVariables)
		{
			$varName = $reqVar.name;
			$relVar = $relDef.variables.$varName;
			if (($null -ne $relVar) -and ($relVar.value -eq 'NA'))
			{
				Write-Verbose ("==> Warning: validation for '{0}' is suppressed." -f $varName);
				continue;
			}
			$relType = $reqVar.relType;
			if ($relType -ne $relTypeAll -and ($isDatabasePipeline -and ($relType -ne $relTypeDb)) -or ((-not $isDatabasePipeline) -and ($relType -ne $relTypeSvc)))
			{
				continue;
			}
			Write-Verbose ("==> Checking {0}" -f $varName);
			Test-GlobalStageVariableUsage -StageVar $reqVar -Stage $relStage;
		}
};
foreach ($relVar in $releaseVariables)
{
	$relType =$relVar.relType;
	if ($relType -eq $relTypeAll -or ($isDatabasePipeline -and ($relType -eq $relTypeDb)) -or ((-not $isDatabasePipeline) -and ($relType -eq $relTypeSvc)))
	{
		Test-VariableIsDefined $relVar.name $relVar.value;
	}
}
if ($isDatabasePipeline)
{
	if ($stageCount -lt $minDbStages)
	{
		Write-Output ("==> Found {0} stages; expected {1}" -f $stageCount,$minDbStages);
		$errorCount++;
	}
}
else
{
	if ($stageCount -lt $minSvcStages)
	{
		Write-Output ("==> Found {0} stages; expected {1}" -f $stageCount,$minSvcStages);
		$errorCount++;
	}
}
Write-Verbose "==> Stage Check";
foreach ($reqStage in $control.stageVariables)
{
	$stageName = $reqStage.stageName;
	$stageRelType = $reqStage.relType;
	$relStage = $environments | Where-Object {$_.name -eq $stageName};
	if ($null -eq $relStage)
	{
		if ($stageRelType -eq $relTypeAll)
		{
			Write-Output ("==> {0}: Missing stage required for all pipelines." -f $stageName);
			$errorCount++;
			continue;
		}
		if ($stageRelType -eq $relTypeSvc -and (-not $isDatabasePipeline))
		{
			Write-Output ("==> {0}: Missing stage required for non-database pipeline." -f $stageName);
			$errorCount++;
			continue;
		}
		continue;
	}
	$reqPriorStageName = $reqStage.follows;
	[array]$relStageConditions = $relStage.conditions | Where-Object conditionType -eq "environmentState";
	$conditionCount = $relStageConditions.Count;
	if ($conditionCount -eq 1)
	{
		$relPriorStageName = $relStageConditions[0].name;
		if ($relPriorStageName -ne $reqPriorStageName)
		{
			Write-Output ("==> {0}: Prior stage must be '{1}', found '{2}'." -f $stageName,$reqPriorStageName,$relPriorStageName);
			$errorCount++;
		}
	}
	elseif ($conditionCount -gt 1)
	{
		Write-Output ("==> {0}: Prior stage must be '{1}', found {2} conditions." -f $stageName,$reqPriorStageName,$conditionCount);
		$errorCount++;
	}
	[array]$relStageApprovers =$relStage.preDeployApprovals;
	[array]$requiredStageApprovers = $reqStage.approvers;
	if ($requiredStageApprovers.Count -ne 0)
	{
		foreach ($requiredStageApprover in $requiredStageApprovers)
		{
			Write-Verbose ("Checking approver '{0}'." -f $requiredStageApprover.name);
			[array]$reqApp = $groups | Where-Object displayName -eq $requiredStageApprover.name;
			if ($reqApp.Count -ne 0)
			{
				$reqAppId = $reqApp[0].originId;
				[array]$relApp = $relStageApprovers.approvals | Where-Object {$_.approver.id -eq $reqAppId};
				if ($relApp.Count -eq 0)
				{
					Write-Output ("==> {0}: Missing required approver '{1}'." -f $stageName,$requiredStageApprover.name);
				}
				else
				{
					Write-Verbose "==> Verifying rank";
					$relRank = $relApp[0].rank;
					$reqRank = $requiredStageApprover.rank;
					if ($relRank -ne $reqRank)
					{
						Write-Output ("==> {0}: Found rank {1} (expected {2}) for approver '{3}'." -f $stageName,$relRank,$reqRank,$requiredStageApprover.name);
						$errorCount++;
					}
				}
			}
			else
			{
				Stop-ProcessError -ErrorMessage "Error in control file.";
			}
		}
	}
	else
	{
		if ($relStageApprovers.Count -eq 1 -and ($null -ne $relStageApprovers[0].approvals.approver))
		{
			Write-Output ("==> {0}: Found approver; none should be specified." -f $stageName);
			$errorCount++;
		}
		elseif($relStageApprovers.Count -gt 1)
		{
			Write-Output ("==> {0}: Found {1} approvers; none should be specified." -f $stageName,$relStageApprovers.Count);
			$errorCount++;
		}
	}
	if ($relStage.executionPolicy.queueDepthCount -ne 1)
	{
		Write-Output ("==> {0}: Deployment queue settings->Subsequent releases->Deploy latest and cancel others was not selected." -f $stageName);
		$errorCount++;
	}
}
if ($errorCount -ne 0)
{
	Write-Output ("==> Found {0} validation errors in '{1}'." -f $errorCount,$PipelineName);
}
else
{
	Write-Output ("==> {0}: No validation errors." -f $PipelineName);
}
