<#
.SYNOPSIS
Update all requested release definitions to require pre-approvals in UAT-EUW.

.DESCRIPTION
The Start-UatManagedPhase script updates all requested release definitions found in -QueryPath to require pre-approvals in UAT-EUW.

.Parameter Release
This is the targeted branch for the release definitions of interest.

.PARAMETER QueryPath
This is the path for the release definitions of interest.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.EXAMPLE
Start-UatManagedPhase -Release 10.5

This updates the release definitions in the "\CTP\Release 10.5" release pipeline folder.

.EXAMPLE
Start-UatManagedPhase -QueryPath @("\CTP\Release 10.5")

This updates the release definitions in the "\CTP\Release 10.5" release pipeline folder.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release='0.0',
	[Parameter(Mandatory=$false)]
	[string[]]$QueryPaths = @(''),
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Function Find-Project()
{
	param(
		[string]$projectName
	)
	Write-Verbose ("Find Project '{0}'" -f $projectName);
	$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
	$projectsUrl = "$($tfsBaseUrl)_apis/projects?api-version=5.1";
	$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header;
	$projects.value |
		Sort-Object -Property name |
		ForEach-Object {
			Write-Verbose ("`t{0}" -f $_.name);
			if ($projectName -eq $_.name)
			{
				return $true;
			}
		};
	return $false;
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
if (($Release -eq '0.0') -and (($QueryPaths.Length) -eq 0 -or ($QueryPaths[0] -eq '')))
{
	Stop-ProcessError "Must provide -Release or -QueryPaths parameter";
}
if (($QueryPaths.Length) -eq 1 -and ($QueryPaths[0] -eq ''))
{
	$releasePath = "\CTP\Release {0}" -f $Release;
	$QueryPaths = @($releasePath);
}
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
if (!(Find-Project($ProjectName)))
{
	$errorMessage = "'{0}' does not exist in account '{1}'. " -f $ProjectName,$Account;
	Stop-ProcessError -errorMessage $errorMessage;
}
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$uatPrereleaseApproverName = '[EYGlobalTaxPlatform]\Release Pre-Approvers - UAT';
$groups = Get-GroupsForOrganization -AuthHeader $authHeader;
[array]$releaseApprovers = $groups.value | Where-Object principalName -eq $uatPrereleaseApproverName;
if ($releaseApprovers.Count -ne 1)
{
	$errorMessage = "Found {0} matches for '{1}'; expected 1." -f $releaseApprovers.Count,$uatPrereleaseApproverName;
	Stop-ProcessError -errorMessage $errorMessage;
}
$uatPreapprover = [PSCustomObject]@{
	descriptor  = $releaseApprovers[0].descriptor;
	displayName = $releaseApprovers[0].principalName;
	isContainer = $true;
	id = $releaseApprovers[0].originId;
};
$projectUrl = "{0}{1}" -f $tfsBaseUrl,$ProjectName;
foreach ($queryPath in $QueryPaths)
{
	$result = Get-AllReleaseDefinitionsByPath -Path $queryPath -ProjectUrl $projectUrl -AuthHeader $header;
	$relDefs = $result.value;
	if ($relDefs.count -gt 0)
	{
		Write-Output ("{0}{1} {2} release def founds" -f $ProjectName,$queryPath,$relDefs.count);
		$relDefs |
			Sort-Object -Property name |
			ForEach-Object {
				$isChanged = $false;
				$relDefId = $_.id;
				$relDefName = $_.name;
				Write-Output "Reviewing `t$($relDefName)";
				# get the full definition
				$global:relDef = Get-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $header;
				# remove properties that don't update
				$relDef.PSObject.Properties.Remove('createdBy')
				$relDef.PSObject.Properties.Remove('createdOn')
				$relDef.PSObject.Properties.Remove('modifiedBy')
				$relDef.PSObject.Properties.Remove('modifiedOn')
				$isChanged = $false;
				# Iterates through all stages
				$relenvs = $relDef.environments;
				foreach ($relEnv in $relEnvs)
				{
					$stageName = $relEnv.name;
					if ($stagename -eq 'UAT-EUW')
					{
						$preDeployApprovals = $relEnv.preDeployApprovals;
						$approvals = $preDeployApprovals.approvals;
						$approvalOptions = $preDeployApprovals.approvalOptions;
						if ($approvals.Count -ne 2)
						{
							$isChanged = $true;
							$approver2 = $approvals[0];
							$approver2.rank = 1;
							$approver1 = [PSCustomObject]@{
								rank = 1;
								isAutomated = $false;
								isNotificationOn = $false;
								approver = $uatPreapprover;
							}
							$relEnv.preDeployApprovals.approvals = @($approver1,$approver2);
							$relEnv.preDeployApprovals.approvalOptions.requiredApproverCount = 1;
						}
					};
				};
				if ($isChanged -and $PSCmdlet.ShouldProcess($relDefName,"Updating"))
				{
					Write-Output "Updating `t$($relDefName)";
					# Update the pipeline
					$result = Update-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ReleaseDefinition $relDef -ProjectUrl $projectUrl -AuthHeader $header;
					if ($isVerbose)
					{
						Write-AsJson -CustomObject $result;
					}
				}
			};
	};
}
