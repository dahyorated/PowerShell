<#
.Synopsis
Update the version for the Build Versioning Task in all specified build pipelines.

.Description
The Update-ReleaseDefinitionTaskVersioning script updates all build definitions where the version for Azure PowerShell task -TaskId is not version -Version. If -Version is already being used, there is no update.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
Update-ReleaseDefinitionTaskVersioning -TaskId '19e979ba-6e06-49bb-9c3c-03ebdcb6812d' -Version '3.*';

This would update all build definitions that reference Task ID '19e979ba-6e06-49bb-9c3c-03ebdcb6812d' to use version '3.*'.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[ValidateLength(36,36)]
	[string]$TaskId = '19e979ba-6e06-49bb-9c3c-03ebdcb6812d',
	[Parameter(Mandatory=$false)]
	[string]$Version = '2.*',
	[Parameter(Mandatory=$false)]
	[string]$DisplayName = '',
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

# TODO: Major Changes (Build ==> Release)
# TODO: Add set of specific pipelines to change.
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting Update-ReleaseDefinitionVersioning for TaskId '{0}'." -f $TaskId);
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeaderX = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $buildAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
# List URL by Task Id Usage
# https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/list?view=azure-devops-rest-5.1#builddefinitionreference
# GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions?queryOrder={queryOrder}&$top={$top}&taskIdFilter={taskIdFilter}&api-version=5.1
$uriTemplate = "{0}/_apis/build/definitions?queryOrder=definitionNameAscending&`$top=500&taskIdFilter={1}&api-version=5.1";
$uri = $uriTemplate -f $projectUrl,$TaskId;
$result = Invoke-RestMethod $uri -Method Get -ContentType "application/json" -Headers $AuthHeader;
[array]$buildDefs = $result.value;
if ($buildDefs.count -gt 0)
{
	Write-Output "$($buildDefs.count) build definitions found";
	$buildDefs |
		ForEach-Object {
			$buildDef = $_;
			$buildDefId = $buildDef.id;
			$buildDefName = $buildDef.name;
			$isModified = $false;
			$showBuildDef = $true;
			# TODO: Convert next two lines to DevOps function
			$buildDefFullUrl = "$projectUrl/_apis/build/definitions/$($buildDefId)?api-version=5.1";
			$buildDefFull = Invoke-RestMethod $buildDefFullUrl -Method Get -ContentType "application/json" -Headers $AuthHeader;
			$buildDefFull.process.phases | Foreach-Object {
				$phaseName = $_.name;
				$showPhaseName = $true;
				$_.steps | Foreach-Object {
					$step = $_;
					if (($step.task.id -eq $TaskId) -and ($step.task.versionSpec -ne $Version))
					{
						$task = $step.task;
						$isModified = $true;
						if ($showBuildDef)
						{
							$showBuildDef = $false;
							Write-Output $buildDefName;
						}
						if ($showPhaseName)
						{
							$showPhaseName = $false;
							Write-Verbose "==>`t$phaseName";
						}
						$message = "`t==>`t{0}: Version {1}" -f $_.name,$_.version;
						Write-Verbose $message;
						$task.versionSpec = $Version;
						$step.displayName = "Task group: Build Versioning";
					}
				};
			};
			if ($isModified)
			{
				$buildDefFull.PSObject.Properties.Remove('createdBy');
				$buildDefFull.PSObject.Properties.Remove('createdOn');
				$buildDefFull.PSObject.Properties.Remove('modifiedBy');
				$buildDefFull.PSObject.Properties.Remove('modifiedOn');
				$message = "==>`tUpdating $($buildDefName)"
				if ($PSCmdlet.ShouldProcess($message))
				{
					Write-Output $message;
					# Update the pipeline
					$updateJson = $buildDefFull | ConvertTo-Json -Depth 100 -Compress;
					# PUT https://vsrm.dev.azure.com/{organization}/{project}/_apis/build/definitions?api-version=5.1
					try
					{
						$result = Invoke-RestMethod $buildDefFullUrl -Method Put -ContentType "application/json" -Headers $AuthHeader -Body $updateJson;
						if ($result.id -ne $buildDefId)
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
