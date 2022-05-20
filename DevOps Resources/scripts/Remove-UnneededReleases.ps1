<#
.Synopsis
Remove unneeded releases.

.Description
The Remove-UnneededReleases script removes unneeded releases for the release definitions in -ReleaseDefinitions.

.Parameter ReleaseDefinitions
This is the set of release pipeline definitions to be processed. Each element is:
- A specific release definition; or
- A folder wild-card (e.g., '\CTP\Release 9.5\*').

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
Remove-UnneededReleases -ReleaseDefinitions @('\CTP\Release 8.4\entityservice-ctp-R8.4');

Remove unneeded releases for 'entityservice-ctp-R8.4'.

.Example
Remove-UnneededReleases -ReleaseDefinitions @('\CTP\Release 8.4\*');

Remove unneeded releases for all release definitions in '\CTP\Release 8.4\'.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true,ValueFromPipeline)]
	[string[]]$ReleaseDefinitions,
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Class OpStatus
{
	[bool]$IsPending;
	[string]$Stage;
	OpStatus ([bool]$isPending, [string]$stage)
	{
		$this.IsPending = $isPending;
		$this.Stage = $stage;
	}
}

Function Get-OpStatus
{
	param(
		$deployment
	)
	[array]$opStatus = $deployment.operationStatus;
	$isPending = $false;
	for ($i = 0; $i -lt $opStatus.Count; $i++)
	{
		if ($pendingOpsStatuses -contains $opStatus[$i])
		{
			$stage = $deployment.releaseEnvironment[$i].name;
			$isPending = $true;
			break;
		}
	}
	return [OpStatus]::new($isPending,$stage);
}

Function Remove-ReleaseById
{
	[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$relId,
		[Parameter(Mandatory=$true,Position=1)]
		[string]$relDefName,
		[Parameter(Mandatory=$true,Position=2)]
		[string]$relName
	)
	$message = "=> Deleting '{0} {1}'" -f $relDefName,$relName;
	if ($PSCmdlet.ShouldProcess($message))
	{
		# This URL is not documented. It was extracted from the DevOps UI.
		$delRelUrl = "$script:projectUrl/_apis/Release/releases/$($relId)?comment=Automated%20CleanUp&api-version=5.1";
		try
		{
			$delResult = Invoke-RestMethod $delRelUrl -Method Delete -ContentType "application/json" -Headers $script:authHeader;
			Write-Verbose $delResult;
			Write-Output $message;
			$script:deletedCount++;
		}
		catch
		{
			$script:errorCount++;
			$errorDetailsMessage = $_.ErrorDetails.Message | ConvertFrom-Json;
			$typeKey = $errorDetailsMessage.typeKey;
			Write-Output ("=> Delete for '{0} {1}' failed." -f $relDefName,$relName);
			if ($typeKey -eq 'ReleaseDeletionNotAllowedException')
			{
				Write-Output ("`t=> {0}" -f $errorDetailsMessage.message);
			}
			else
			{
				Write-Output ("`t=> {0}" -f $_.Exception.Message);
				Write-Output ("`t=> {0}" -f $_.ErrorDetails.Message);
			}
		}
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$deletedCount = 0;
$skippedCount = 0;
$errorCount = 0;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$pendingOpsStatuses = @('Pending','EvaluatingGates');
# https://docs.microsoft.com/en-us/rest/api/azure/devops/release/definitions/list?view=azure-devops-rest-5.1

$ReleaseDefinitions | ForEach-Object {
	$isWildCard = $false;
	$relDefName = $_;
	Write-Output ("Processing: '{0}'." -f $relDefName);
	if ($relDefName.EndsWith("*"))
	{
		Write-Output "==> Expanding wild-card.";
		$isWildCard = $true;
		$relDefName = $relDefName.TrimEnd("*").TrimEnd("\");
	}
	elseif (-not $relDefName.EndsWith("\"))
	{
		$pathParts = $relDefName -split '\\';
		$last = $pathParts.Length -1;
		$leafName = $pathParts[$last];
		$relDefName = $relDefName.TrimEnd($leafName);
		$relDefName = $relDefName.TrimEnd("\");
	}
	else
	{
		$isWildCard = $true;
		$relDefName = $relDefName.TrimEnd("\");
	}
	$projectUrl = "$tfsBaseUrl$($ProjectName)";
	$allDefinitions = Get-AllReleaseDefinitionsByPath -Path $relDefName -ProjectUrl $projectUrl -AuthHeader $authHeader;
	if ($allDefinitions.Count -eq 0)
	{
		$errorMessage = "No release definition for '{0}'." -f $relDefName;
		Stop-ProcessError $errorMessage;
	}
	Write-Verbose $allDefinitions.Count;
	if ($isWildcard)
	{
		[array]$relDefs = $allDefinitions.value;
	}
	else
	{
		[array]$relDefs = $allDefinitions.value | Where-Object {$_.name -eq $leafName};
	}
	$relsToKeep = New-Object -TypeName System.Collections.ArrayList;
	$relsToDelete = New-Object -TypeName System.Collections.ArrayList;
	$relDefs | Sort-Object name | ForEach-Object {
		$relDef = $_;
		$relDefId = $relDef.id;
		$relsToDelete.Clear();
		$relsToKeep.Clear();
		Write-Verbose ("Checking for unneeded releases for release definition'{0}'." -f $relDef.name);
		# Get all releases
		$allReleases = Get-AllReleasesForDefinition -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $authHeader -MaxReleases 250;
		$allDeployments = Get-AllDeploymentsForDefinition -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $authHeader -MaxDeployments 250;
		$allDeployments.value| ForEach-Object {
			$releaseInfo = $_.release;
			$relId = $releaseInfo.id;
			Write-Verbose ("{0}: {1}" -f $releaseInfo.id,$releaseInfo.name);
			if ($relsToDelete -notcontains $relId)
			{
				$newIndex = $relsToDelete.Add($relId);
				Write-Verbose ("relsToDelete[{0}] = {1}" -f $newIndex,$relId);
			}
		}
		$allReleases.environments | ForEach-Object {
			$lastReleases = $_.lastReleases;
			if ($lastReleases.Count -gt 0)
			{
				$relId = $lastReleases[0].id;
				if ($relsToKeep -notcontains $relId)
				{
					$newIndex = $relsToKeep.Add($relId);
					Write-Verbose ("relsToKeep[{0}] = {1}" -f $newIndex,$relId);
				}
				if ($relsToDelete -contains $relId)
				{
					$relsToDelete.Remove($relId);
				}
			}
		}
		if ($null -ne $allReleases.releases)
		{
			$allReleases.releases | ForEach-Object{
				$rel = $_;
				$relId = $rel.Id;
				$relName = $rel.name;
				$keepForever = $rel.keepForever;
				if ($relsToKeep -notcontains $relId)
				{
					[array]$deployment = $allDeployments.value | Where-Object{$_.release.id -eq $relId};
					if ($deployment.release.Count -ne 0)
					{
						$relName = $deployment.release[0].name;
						$opStatus = Get-OpStatus -deployment $deployment;
						if ($opstatus.IsPending)
						{
							Write-Output ("=> Skipping '{0} {1}' due to pending operation in {2}." -f $relDef.name,$relName,$opstatus.Stage);
							$skippedCount++;
						}
						elseif ($keepForever)
						{
							Write-Output ("=> Skipping '{0} {1}' due to retain indefinitely lock." -f $relDef.name,$relName);
							$skippedCount++;
						}
						else
						{
							$output = Remove-ReleaseById -relId $relId -relDefName $relDef.name -relName $relName;
							Write-Output $output;
						}
					}
					if ($relsToDelete -contains $relid)
					{
						$relsToDelete.Remove($relId);
					}
				}
			}
		}
		$relsToDelete | ForEach-Object{
			$relId = $_;
			if ($relsToKeep -notcontains $relId)
			{
			$deployment = $allDeployments.value | Where-Object{$_.release.id -eq $relId};
				$relName = $deployment.release[0].name;
				$opStatus = Get-OpStatus -deployment $deployment;
				if ($opStatus.IsPending)
				{
					Write-Output ("=> Skipping '{0} {1}' due to pending operation in {2}." -f $relDef.name,$relName,$opStatus.Stage);
					$skippedCount++;
				}
				else
				{
					$output = Remove-ReleaseById -relId $relId -relDefName $relDef.name -relName $relName;
					Write-Output $output;
				}
			}
		}
	}
}
Write-Output ("==> Deleted: {0}, Skipped: {1}, Errors: {2}" -f $deletedCount,$skippedCount,$errorCount);
