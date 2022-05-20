<#
.SYNOPSIS
Clone a CTP pipeline into a release folder.

.DESCRIPTION
The Clone-ReleasePipeline script clones the -PipeLineName CTP pipeline into the release folder specified by -Release.

.PARAMETER PipelineName
This is the name of the pipeline to clone.

.PARAMETER Release
This is the current release and must be in the form "9.9".

.PARAMETER SourcePath
This is the source path and must include the leading "\".

.PARAMETER TargetPath
This is the target path and must include the leading "\".

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.PARAMETER JsonFile
This is the current release definition status file.

.Parameter StartBuild
If specified, a build is started for the newly cloned pipeline in the -Release branch.

.Parameter AddPostDeploymentApproval
If specified, then a post deployment approval is added for QAT-EUW.

.EXAMPLE
Clone-ReleasePipeline -PipelineName 'Global Tax Platform - App - APIM - Portal (ctp)' -Release 9.1

This creates a clone of the 'Global Tax Platform - App - APIM - Portal (ctp)' pipeline in the '\CTP\Release 9.1' folder.
This is the most commonly used version.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true,ValueFromPipeline)]
	[string]$PipelineName,
	[Parameter(Mandatory=$false)]
	[string]$Release = "9.9",
	[Parameter(Mandatory=$false)]
	[string]$SourcePath = "\CTP",
	[Parameter(Mandatory=$false)]
	[string]$TargetPath = "",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN},
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonFile = "$pwd\ReleaseDefinitionStatus.json",
	[Parameter()]
	[switch]$StartBuild,
	[switch]$AddPostDeploymentApproval
)

Function Get-ReleaseDefinitionStatus
{
	if (-not (Test-Path -Path $JsonFile -PathType Leaf))
	{
		Get-ReleaseStatus -Force;
	}
	return Get-Content -Path $JsonFile | ConvertFrom-Json;
}

Function Get-MatchingReleaseDefinition
{
	param (
		[string]$relDefName
	)
	# find a matching $rdStatus;
	$matches =  [regex]::Match($relDefName,"(.*)-[Rr][0-9]*\.[0-9]*");
	if ($matches -and ($matches.Groups.Count -eq 2))
	{
		$matchRelDefName = $matches.Groups[1].Value;
	}
	else
	{
		$matchRelDefName = $relDefName;
	}
	$matchStatuses = $rdStatuses.Where{$_.definitionName -eq $matchRelDefName};
	if (($null -ne $matchStatuses) -and ($matchStatuses.Count -eq 1))
	{
		$rdStatus = $matchStatuses[0];
	}
	else
	{
		Write-Host "No match for $($relDefname)" -ForegroundColor Red;
		Exit 1;
	}
	return $rdStatus;
}

Function Find-ReleaseDefinition
{
	param(
		[string]$path,
		[string]$pipelineName,
		[string]$release
	)
	$found = $false;
	$pathQuery = $pathQuery = "path={0}" -f $path;
	$relDefName = "$($pipelineName)-R$($Release)";
	$relDefUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?searchText=$relDefName&$pathQuery&isExactNameMatch=true&api-version=5.1";
	$global:result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header;
	if (($null -ne $result) -and ($result.Count -gt 0))
	{
		$found = $true;
	}
	return $found;
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
if ([string]::IsNullOrWhiteSpace($TargetPath))
{
	$TargetPath = "{0}\Release {1}" -f $SourcePath,$Release
}
Write-Output "Creating clone of '\CTP\$($PipelineName)' in '$TargetPath'.";
$found = Find-ReleaseDefinition -path $TargetPath -pipelineName $PipelineName -release $Release;
if ($found)
{
	Write-Output "Clone already exists - skipping.";
	return;
}
$releaseBranch = "Release/PI$($Release)";
$rdStatuses = Get-ReleaseDefinitionStatus;
$rdStatus = Get-MatchingReleaseDefinition $PipelineName;
# The DEV code is always deployed from the master definition
$relDefId = $rdStatus.dev.DefId;
$relDef = Get-ReleaseDefinitionById $relDefId $projectUrl $header;
# remove properties that don't update
$relDef.PSObject.Properties.Remove('createdBy')
$relDef.PSObject.Properties.Remove('createdOn')
$relDef.PSObject.Properties.Remove('modifiedBy')
$relDef.PSObject.Properties.Remove('modifiedOn')
$relDef.PSObject.Properties.Remove('url')
# make changes
$relDef.id = 0;
$relDef.path = $TargetPath;
$relDef.name = "$($relDef.name)-R$($Release)";
$relDef.revision = 1;
$relDef.description = "Clone of '\CTP\$($PipelineName)'";
$relDef.source = "restApi";
$dev = $relDef.environments | Where-Object {$_.name -eq 'DEV-EUW'};
$qat = $relDef.environments | Where-Object {$_.name -eq 'QAT-EUW'};
$qat.conditions = $dev.conditions;
$devConditionsToCopy = $dev.conditions | Where-Object conditionType -ne 'artifact';
$newDevConditions = $devConditionsToCopy | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json;
if ($devConditionsToCopy.Length -lt 2)
{
	$qat.conditions = @($newDevConditions);
}
else
{
	$qat.conditions = $newDevConditions;
}
$qat.schedules = @();
$qat.preDeploymentGates.gates = @();
$qat.preDeploymentGates.gatesOptions = $null;
$qat.preDeploymentGates.id = 0;
$qatApproverName = "[EYGlobalTaxPlatform]\Release Approvers- QA";
$groups = Get-GroupsForOrganization -AuthHeader $header;
[array]$releaseApprovers = $groups.value | Where-Object principalName -eq $qatApproverName;
if ($releaseApprovers.Count -ne 1)
{
	$errorMessage = "Found {0} matches for '{1}'; expected 1." -f $releaseApprovers.Count,$qatApproverName;
	Stop-ProcessError -errorMessage $errorMessage;
}
$qaApprover = [PSCustomObject]@{
	descriptor  = $releaseApprovers[0].descriptor;
	displayName = $releaseApprovers[0].principalName;
	isContainer = $true;
	id = $releaseApprovers[0].originId;
};
$qat.preDeployApprovals.approvals[0] | Add-Member -NotePropertyName approver -NotePropertyValue $qaApprover;
$qat.preDeployApprovals.approvals[0].isAutomated = $false;
$qat.preDeployApprovals.approvalOptions.releaseCreatorCanBeApprover = $true;
if ($AddPostDeploymentApproval)
{
	$qat.postDeployApprovals.approvals[0] | Add-Member -NotePropertyName approver -NotePropertyValue $qaApprover;
	$qat.postDeployApprovals.approvals[0].isAutomated = $false;
	$qat.postDeployApprovals.approvalOptions.releaseCreatorCanBeApprover = $true;
}
[array]$environments = $relDef.environments |
	Where-Object {($_.name -ne 'DEV-EUW') -and ($_.name -ne 'DEV-USE') -and ($_.name -notlike 'euwdev-*') -and ($_.name -notlike 'usedev-*')};
$newRank = 0;
$errorCount = 0;
$environments |
	Sort-Object rank |
	ForEach-Object {
		$_.rank = ++$newRank;
		$stageName = $_.name.Trim();
		if ($stageName -ne $_.name)
		{
			Write-Output ("Stage name '{0}' contains spaces." -f $_.name);
			$errorCount++;
		}
};
if ($isVerbose)
{
	$environments |
		Sort-Object rank |
		ForEach-Object {
		Write-Output "Stage '$($_.name)': rank = $($_.rank)";
	}
}
if ($environments.Count -lt 2)
{
	Write-output ("There are only {0} environments. Cannot proceed." -f $environments.Count);
	$errorCount++;
}
$relDef.environments = $environments;
$trigger = $relDef.triggers | Where-Object{$_.triggerType -eq 'artifactSource'};
if ($null -eq $trigger)
{
	Write-Output "Continuous deployment trigger is disabled.";
	$errorCount++;
}
else
{
	$triggerCondition = $trigger.triggerConditions | Where-Object {$_.sourceBranch -eq 'develop'};
	if ($null -eq $triggerCondition)
	{
		Write-Output "Continuous deployment trigger is not filtered by 'develop'";
		$errorCount++;
	}
	else
	{
		$triggerCondition.sourceBranch = $releaseBranch;
	}
}
if ($errorCount -ne 0)
{
	$message = "There are {0} errors in the '\CTP\{1}' pipeline." -f $errorCount,$PipelineName;
	Stop-ProcessError $message;
}
if ($null -eq $relDef.comment)
{
	$relDef | Add-Member -NotePropertyName comment -NotePropertyValue "";
}
$relDef.comment = "Cloned '{0}' to release '{1}' on {2}." -f $PipelineName,$Release,(Get-Date -Format u);
# POST https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?api-version=5.1
$postUrl = "$projectUrl/_apis/release/definitions?api-version=5.1";
$jsonBody = $relDef | ConvertTo-Json -Depth 100 -Compress;
try
{
	$cloneDef = Invoke-RestMethod $postUrl -Method Post -ContentType "application/json" -Headers $header -Body $jsonBody;
}
catch
{
	Write-AsJson -CustomObject $_.ErrorDetails;
	$errorMessage = "==> Clone Post failed for '{0}', exception: {1}" -f $PipelineName,$_.Exception.Message;
	Stop-ProcessError -errorMessage $errorMessage;
}
if ($StartBuild)
{
	$buildArtifact = $cloneDef.artifacts | Where-Object isPrimary;
	$buildPipelineName = $buildArtifact.definitionReference.definition.name;
	$buildPipelineId = $buildArtifact.definitionReference.definition.id;
	New-ReleaseBuild -Release $Release -PipelineId $buildPipelineId -PipelineName $buildPipelineName;
}
