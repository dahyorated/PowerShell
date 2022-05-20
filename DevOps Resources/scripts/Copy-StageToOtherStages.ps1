<#
.Synopsis
Copy the specified stage settings in a release pipeline to all other stages in the release pipeline.

.Description
The Copy-StageToOtherStages script copies the -SourceStage stage settings in the -PipelineName release pipeline to all other stages in the release pipeline.

.Parameter PipelineName
This is the name of the release pipeline.

.Parameter Path
This is the folder (with no trailing"\") that contains the pipeline.

.Parameter SourceStage
This is the stage that is the template for all other stages.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param (
	[Parameter(Mandatory=$true,Position=0)]
	[string]$PipelineName,
	[Parameter(Mandatory=$false)]
	[string]$Path = "\CTP",
	[Parameter(Mandatory=$false)]
	[string]$SourceStage = "DEV-EUW",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Find-ReleaseDefinition
{
	param(
		[string]$Path,
		[string]$PipelineName,
		[string]$Release
	)
	$found = $false;
	$pathQuery = $pathQuery = "path={0}" -f $path;
	$relDefUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?searchText=$pipelineName&$pathQuery&isExactNameMatch=true&api-version=5.1";
	$script:result = Invoke-RestMethod $relDefUrl -Method Get -ContentType "application/json" -Headers $header;
	if (($null -ne $result) -and ($result.Count -gt 0))
	{
		$found = $true;
	}
	return $found;
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$errorCount = 0;
$modifiedStages = 0;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$found = Find-ReleaseDefinition -Path $Path -PipelineName $PipelineName -Release $Release;
if (-not $found)
{
	Write-Output ("Could not find '{0}\{1}'." -f $Path,$PipelineName);
	Exit;
}
$relDefId = $result[0].value.id;
$global:relDef = Get-ReleaseDefinitionById $relDefId $projectUrl $header;
# remove properties that don't update
$relDef.PSObject.Properties.Remove('createdBy')
$relDef.PSObject.Properties.Remove('createdOn')
$relDef.PSObject.Properties.Remove('modifiedBy')
$relDef.PSObject.Properties.Remove('modifiedOn')
$relDef.PSObject.Properties.Remove('url')
# make changes
$srcEnvironment = $relDef.environments | Where-Object name -eq $SourceStage;
$srcDeployPhases = [array]$srcEnvironment.deployPhases;
$workflowTasks = $srcDeployPhases[0].workflowTasks | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json;
$agent = $srcDeployPhases[0].deploymentInput.agentSpecification;
if ($null -ne $agent)
{
	$agentIdentifier = $agent.identifier;
	$agentspecification = [PSCustomObject]@{
		identifier = $agentIdentifier
	};
}
else
{
	$agentIdentifier = $null;
	$agentspecification = $null;
}
$oauthSetting = $srcDeployPhases[0].deploymentInput.enableAccessToken;
$queueId = $srcDeployPhases[0].deploymentInput.queueId;
# update pipeline
foreach ($environment in $relDef.environments)
{
	$stageName = $environment.name;
	if ($stageName -eq $SourceStage)
	{
		continue;
	}
	Write-Output ("Modifying '{0}' stage." -f $stageName);
	$modifiedStages++;
	$deployPhases = $environment.deployPhases;
	if ($null -ne $agent)
	{
		# change agent
		if ($null -eq $deployPhases[0].deploymentInput.agentSpecification.value)
		{
			$environment.deployPhases[0].deploymentInput | Add-Member -NotePropertyName agentspecification -NotePropertyValue $agentspecification -Force;
		}
		$environment.deployPhases[0].deploymentInput.agentSpecification.identifier = $agentIdentifier;
	}
	$environment.deployPhases[0].deploymentInput.queueId = $queueId;
	# change OAUth setting
	$environment.deployPhases[0].deploymentInput.enableAccessToken = $oauthSetting;
	# change tasks
	$environment.deployPhases[0].workflowTasks = [array]$workflowTasks;
}
if ($errorCount -ne 0)
{
	$filename = "Put-Body-{0}.json" -f $PipelineName;
	$relDef | ConvertTo-Json -Depth 100 | Out-File -FilePath $filename -Force -WhatIf:$false;
	$message = "There are {0} errors in the '\CTP\{1}' pipeline." -f $errorCount,$PipelineName;
	Stop-ProcessError $message;
}
if ($null -eq $relDef.comment)
{
	$relDef | Add-Member -NotePropertyName comment -NotePropertyValue "";
}
$relDef.comment = "Copied {0} stage to {1} other stages." -f $SourceStage,$modifiedStages;
# PUT https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?api-version=5.1
$putUrl = "$tfsBaseUrl$($ProjectName)/_apis/release/definitions?api-version=5.1";
if ($PSCmdlet.ShouldProcess("Update pipeline definition"))
{
	$jsonBody = $relDef | ConvertTo-Json -Depth 100 -Compress;
	$updatedDef = Invoke-RestMethod $putUrl -Method Put -ContentType "application/json" -Headers $header -Body $jsonBody;
	$filename = "Put-Body-{0}.json" -f $PipelineName;
	$updatedDef | ConvertTo-Json -Depth 100 | Out-File -FilePath $filename -Force -WhatIf:$false;
}
else
{
	$filename = "Put-Body-{0}.json" -f $PipelineName;
	$relDef | ConvertTo-Json -Depth 100 | Out-File -FilePath $filename -Force -WhatIf:$false;
}
