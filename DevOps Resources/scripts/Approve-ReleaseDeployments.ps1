<#
.SYNOPSIS
Gets the pending approvals and provides an interactive opportunity to approve each one.

.DESCRIPTION
This gets the pending approvals and provides an interactive opportunity to approve each one.
The default response to all interactive input is "No" to prevent accidental deployments.

Uses REST APIs defined in https://docs.microsoft.com/en-us/rest/api/azure/devops/release/approvals/list?view=azure-devops-rest-5.1#approvalstatus

.PARAMETER TargetStage
This is the target stage used to filter the results. The supported stages are 'QAT', 'UAT', 'STG', and 'PRD'.

.PARAMETER Filter
This is the tail of a filter to match release definition names.
- A value of '' matches everything.
- A value of '-R9.9' matches all release definitions in release 9.9.

.PARAMETER Comment
This is the comment to associate with all approvals.
It defaults to "Promotion to $($TargetStage)".

.Parameter DeploymentType
This is the type of deployment.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.PARAMETER JsonReleaseDefinitionStatus
This is the current release definition status file.

.PARAMETER IgnoreDev
This forces the validation to ignore the DEV stage version.
This is used during the Regression Phase when -TargetStage is 'QAT'.

.PARAMETER IgnoreQat
This forces the validation to ignore the QAT stage version.
This is used during the UAT Phase when -TargetStage is 'UAT'.

.PARAMETER Refresh
This forces the -JsonFile to be refreshed using Get-ReleaseStatus -NoExcel'.

.PARAMETER ShowUrl
This shows the URL for each approved release.

.PARAMETER LaunchUrl
This launches the URL for each approved release.

.PARAMETER NoFilter
This causes the content of -Filter to be ignored.

.PARAMETER WhatIf
This shows the promotion candidates, but does not approve any of them.

.EXAMPLE
Approve-ReleaseDeployments -TargetStage 'UAT' -Filter '-R8.4'
This processes all pending approvals for deployment to UAT for pipelines that end in "-R8.4".

.EXAMPLE
Approve-ReleaseDeployments -TargetStage 'UAT' -Filter '-R8.4' -WhatIf
This shows, but does not approve, all pending approvals for deployment to UAT for pipelines that end in "-R8.4".

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True,Position=1)]
	[ValidateSet('QAT','UAT','PRF','DMO','STG','PRD')]
	[string]$TargetStage,
	[Parameter(Mandatory=$False,Position=2)]
	[string]$Filter = '-R8.4',
	[Parameter(Mandatory=$False)]
	[string]$Comment = '',
	[Parameter(Mandatory=$False)]
	[ValidateSet('preDeploy','postDeploy')]
	[string]$DeploymentType = 'preDeploy',
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
	[System.IO.FileInfo]$JsonReleaseDefinitionStatus = "$pwd\ReleaseDefinitionStatus.json",
	[switch]$WhatIf,
	[switch]$IgnoreDev,
	[switch]$IgnoreQat,
	[switch]$Refresh,
	[switch]$ShowUrl,
	[switch]$LaunchUrl,
	[switch]$NoFilter
)

Function Approve-Release
{
	param(
		[string]$approvalId
	)
	Write-Output "Processing Approval $approvalId";
	if ($ShowUrl)
	{
		Write-Host "$($relDefName): $($relUrl)" -ForegroundColor Green;
	}
	# PATCH https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/approvals/{approvalId}?api-version=5.1
	$approvalUrl = $approvalUrlFormat -f "/$($approvalId)?";
	$result = Invoke-RestMethod $approvalUrl -Method Patch -ContentType "application/json" -Headers $header -Body $approvalJsonBody;
	Write-Verbose $result;
	if ($LaunchUrl)
	{
		Start-Process -FilePath "$relUrl";
	}
}

Function Get-ReleaseDefinitionStatusFromJson
{
	if (-not (Test-Path -Path $JsonReleaseDefinitionStatus -PathType Leaf))
	{
		Write-Output "Creating '$($JsonReleaseDefinitionStatus)'."
		Get-ReleaseStatus -Force -NoExcel;
	}
	elseif ($Refresh)
	{
		Write-Output "Refreshing '$($JsonReleaseDefinitionStatus)'."
		Get-ReleaseStatus -NoExcel;
	}
	return Get-Content -Path $JsonReleaseDefinitionStatus | ConvertFrom-Json;
}

Function Get-MatchingReleaseDefinition
{
	param (
		[string]$relDefName
	)
	# find a matching $rdStatus;
	$matches = [regex]::Match($relDefName,"(.*)-[Rr][0-9]*\.[0-9]*");
	if ($matches -and ($matches.Groups.Count -eq 2))
	{
		$matchRelDefName = $matches.Groups[1].Value;
	}
	else
	{
		$matchRelDefName = $relDefName;
	}
	[array]$matchStatuses = $rdStatuses | Where-Object definitionName -eq $matchRelDefName;
	if (($null -ne $matchStatuses) -and ($matchStatuses.Count -eq 1))
	{
		$rdStatus = $matchStatuses[0];
	}
	else
	{
		Write-Host "No match for $($relDefname)" -ForegroundColor Red;
		return $null;
	}
	return $rdStatus;
}

Function Get-SourceStage
{
	param(
		[string]$targetStage
	)
	$sourceStage = switch ($targetStage)
	{
		'PRD' {'STG'}
		'STG' {'UAT'}
		'PRF' {'UAT'}
		'DMO' {'UAT'}
		'UAT' {'QAT'}
		'QAT' {'DEV'}
	};
	return $sourceStage;
}

Function Get-TargetStageVariation
{
	param(
		[string]$targetStage
	)
	$variations = switch ($targetStage)
	{
		'PRD' {@('PRD','prod')}
		'STG' {@('STG','stage')}
		'UAT' {@('UAT')}
		'PRF' {@('PRF')}
		'DMO' {@('DMO')}
		'QAT' {@('QAT','qa')}
		'DEV' {@('DEV')}
	};
	return $variations;
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
$sourceStage = Get-SourceStage $TargetStage;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$rdStatuses = Get-ReleaseDefinitionStatusFromJson;
# REF https://docs.microsoft.com/en-us/rest/api/azure/devops/release/approvals/list?view=azure-devops-rest-5.1
# GET https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/approvals?...&api-version=5.1
$approvalUrlFormat = "$tfsBaseUrl$($ProjectName)/_apis/release/approvals?typeFilter={0}&top={1}&continuationToken={2}&api-version=5.1";
$batchFetch = 100;
$batch = 0;
$continuationToken = 0;
do
{
	$approvalsUrl = $approvalUrlFormat -f $DeploymentType,$batchFetch,$continuationToken;
	$web = Invoke-WebRequest -Uri $approvalsUrl -Method Get -ContentType "application/json"  -Headers $header;
	$result = $web.Content | ConvertFrom-Json;
	$continuationToken = $web.Headers["X-MS-ContinuationToken"];
	if ($isVerbose)
	{
		Write-Output ("URI: {0}" -f $approvalsUrl);
		Write-Output ("Batch {0}: {1} approvals." -f $batch,$result.Count);
	}
	$approvals += $result.Value;
	$batch++;
}
while ($null -ne $continuationToken);
$approvalUrlFormat = "$tfsBaseUrl$($ProjectName)/_apis/release/approvals{0}&api-version=5.1";
Write-Output ("Found {0} pending approvals." -f $approvals.Count);
$approveAll = $false;
$like = "*{0}" -f $Filter;
if ([string]::IsNullOrWhiteSpace($Comment))
{
	$Comment = "Promotion to $($TargetStage)"
}
$approvalBody = @{
	status = "approved"
	comments = $Comment
};
$releaseUrlFormat = "https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_releaseProgress?releaseId={0}";
$approvalJsonBody = $approvalBody | ConvertTo-Json -Depth 100 -Compress;
Write-Verbose "Approval Body: '$approvalJsonBody'";
[array]$targetVariations = Get-TargetStageVariation $TargetStage;
[array]$stageApprovals = $approvals |
	Where-Object { ($NoFilter -or ($_.releaseDefinition.name -like $like)) -and ($_.releaseDefinition.name -notlike "*-main") } |
	Where-Object { $targetVariations -contains (Get-StrippedStageName $_.releaseEnvironment.name) } |
	Sort-Object { $_.releaseDefinition.name } -Unique;
Write-Output ("Found {0} pending approvals for stage '{1}'." -f $stageApprovals.Count,$TargetStage.ToUpper());
foreach ($approval in $stageApprovals) {
	$approvalId = $approval.id;
	$envName = $approval.releaseEnvironment.name;
	$relName = $approval.release.name;
	$relId = $approval.release.id;
	$relUrl = $releaseUrlFormat -f $relId;
	$relDefName = $approval.releaseDefinition.name;
	$relDefId = $approval.releaseDefinition.id;
	$rdStatus = Get-MatchingReleaseDefinition $relDefName;
	if (($null -eq $rdStatus) -or ($IgnoreDev -and ($TargetStage -eq 'QAT')) -or ($IgnoreQat -and ($TargetStage -eq 'UAT')))
	{
		$sourceRelName = $relName;
		$sourceDefId = $relDefId;
	}
	else
	{
		$rdSource = $rdStatus.$sourceStage;
		$sourceRelName = $rdSource.ReleaseName;
		$sourceDefId = $rdSource.DefId;
	}
	$sourceParts = $sourceRelName -split '\\';
	$coreMessage = "$($relDefName)[$($relDefId)]: $($envName) $($relName)[$($relId)]";
	if ($sourceParts[$sourceParts.Count-1] -ne $relName)
	{
		if ($relDefId -ne $sourceDefId)
		{
			Write-Host "'$($coreMessage)' release definition mismatch 'SourceDefId[$($sourceDefId)]'." -ForegroundColor Cyan;
		}
		Write-Host "Expected release name for '$($coreMessage)' is '$sourceRelName'." -ForegroundColor Yellow;
		if ($WhatIf)
		{
			Write-Host "$coreMessage";
		}
		elseif ($approveAll)
		{
				Write-Host "Approving '$coreMessage'";
				Approve-Release $approvalId;
		}
		else
		{
			$answer = Read-Host -Prompt "Process '$($coreMessage)'? (yes|No|all|stop)";
			if ($answer.StartsWith('y'))
			{
				Write-Host "Approving '$coreMessage'";
				Approve-Release $approvalId;
			}
			elseif ($answer.StartsWith('a'))
			{
				Write-Host "Approving '$coreMessage'";
				Approve-Release $approvalId;
				$approveAll = $true;
			}
			elseif ($answer.StartsWith('s'))
			{
				Write-Host "Stopping processing.";
				break;
			}
		}
	}
	elseif ($WhatIf)
	{
		Write-Host "$($coreMessage)";
		if ($ShowUrl)
		{
			Write-Host "$($relDefName): $($relUrl)" -ForegroundColor Green;
		}
		if ($LaunchUrl)
		{
			Start-Process -FilePath "$relUrl";
		}
	}
	elseif ($approveAll)
	{
		Write-Host "Approving '$coreMessage'";
		Approve-Release $approvalId;
	}
	else
	{
		$answer = Read-Host -Prompt "Approve '$coreMessage' (yes|No|all|stop)?";
		if ($answer.StartsWith('y'))
		{
			Write-Host "Approving '$coreMessage'";
			Approve-Release $approvalId;
		}
		elseif ($answer.StartsWith('a'))
		{
			$approveAll = $true;
			Write-Host "Approving '$coreMessage' and all others.";
			Approve-Release $approvalId;
		}
		elseif ($answer.StartsWith('s'))
		{
			Write-Host "Stopping processing.";
			break;
		}
	}
};
