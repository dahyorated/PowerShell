<#
.Synopsis
Update the version for the Azure PowerShell Task in all specified pipelines.

.Description
The Update-ReleaseDefinitionTaskVersion script updates all release definitions in -QueryPaths where the version for an Azure PowerShell task is not version 4.*.

.PARAMETER QueryPaths
This is the path for the release definitions of interest.

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
	[Parameter(Mandatory=$false)]
	[string[]]$QueryPaths = @("\CTP","\CTP\Through DEV-QA","\CTP\Through UAT-Perf","\CTP\Release 9.5"),
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Starting Update-ReleaseDefinitionTaskVersion";
$azPsTaskId = '72a1931b-effb-4d2e-8fd8-f8472a07cb62';
$taskVersion = '4.*';
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$QueryPaths | ForEach-Object {
	$result = Get-AllReleaseDefinitionsByPath -Path $QueryPath -ProjectUrl $projectUrl -AuthHeader $authHeader;
	[array]$relDefs = $result.value;
	if ($relDefs.count -gt 0)
	{
		Write-Output "$($ProjectName)$($queryPath): $($relDefs.count) release definitions found";
		$relDefs |
			Sort-Object -Property name |
			ForEach-Object {
				$relDef = $_;
				$relDefId = $relDef.id;
				$relDefName = $relDef.name;
				$isModified = $false;
				$showRelDef = $true;
				# TODO: Convert next two lines to DevOps function
				$relDefFullUrl = "$projectUrl/_apis/release/definitions/$($relDefId)?api-version=5.1";
				$relDefFull = Invoke-RestMethod $relDefFullUrl -Method Get -ContentType "application/json" -Headers $authHeader;
				$relDefFull.environments | Foreach-Object {
					$stageName = $_.name;
					$showStageName = $true;
					$_.deployPhases | Foreach-Object {
						$_.workflowTasks | ForEach-Object {
							$wft = $_;
							if (($wft.taskId -eq $azPsTaskId) -and ($wft.version -ne $taskVersion))
							{
								$isModified = $true;
								if ($showRelDef)
								{
									$showRelDef = $false;
									Write-Output $relDefName;
								}
								if ($showStageName)
								{
									$showStageName = $false;
									Write-Verbose "==>`t$stageName";
								}
								$message = "`t==>`t{0}: Version {1}" -f $_.name,$_.version;
								Write-Verbose $message;
								$wft.version = $taskVersion;
							}
						};
					};
				};
				if ($isModified)
				{
					$relDefFull.PSObject.Properties.Remove('createdBy');
					$relDefFull.PSObject.Properties.Remove('createdOn');
					$relDefFull.PSObject.Properties.Remove('modifiedBy');
					$relDefFull.PSObject.Properties.Remove('modifiedOn');
					Write-Output "==>`tUpdating $($relDefName)";
					# Update the pipeline
					$updateJson = $relDefFull | ConvertTo-Json -Depth 100 -Compress;
					# PUT https://vsrm.dev.azure.com/{organization}/{project}/_apis/release/definitions?api-version=5.1
					try
					{
						$result = Invoke-RestMethod $relDefFullUrl -Method Put -ContentType "application/json" -Headers $header -Body $updateJson;
						if ($null -eq $result)
						{
							Write-Output "`t==>`Update failed!";
						}
						else
						{
							Write-Output "`t==>`tUpdate succeeded."
						}
					}
					catch
					{
						Write-Output "Update threw exception: $($_.Exception.Message)";
					}
				}
			}
	}
}
