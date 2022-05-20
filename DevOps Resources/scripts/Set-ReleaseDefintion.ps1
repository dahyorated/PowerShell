<#
.Synopsis
Set the selected release defintions using the specified process.

.PARAMETER QueryPath
This is the path for the release definitions of interest.

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
	[Parameter(Mandatory=$false)]
	[string]$QueryPath = "\CTP\POC\BMF 9.9",
	[Parameter(Mandatory=$true)]
	[scriptblock]$Process,
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting {0}." -f [System.IO.Path]::GetFileNameWithoutExtension($PSCmdlet.MyInvocation.InvocationName));
$conditionStageName = 'STG-EUW';
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$allRelDefs = Get-AllReleaseDefinitionsByPath -Path $QueryPath -ProjectUrl $projectUrl -AuthHeader $authHeader;
[array]$relDefs = $allRelDefs.value;
if ($relDefs.count -gt 0)
{
	$sortedRelDefs = $relDefs | Sort-Object -Property name;
	Write-Output "$($ProjectName)$($queryPath): $($relDefs.count) release definitions found";
	foreach ($relDef in $sortedRelDefs)
	{
		$relDefId = $relDef.id;
		$relDefName = $relDef.name;
		Write-Output ("==> Reviewing '{0}'." -f $relDefName);
		$isModified = $false;
		$relDefFull = Get-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $authHeader;
		$processResults = . $Process;
		$isModified = $processResults.IsModifed;
		$relDefFull = $processResults.RelDef;
		[array]$writeOutputs = $processResults.WriteOutput;
		foreach ($writeOutput in $writeOutputs)
		{
			Write-Output ("`t==> {0}" -f $writeOutput);
		}
		if ($isModified -and $PSCmdlet.ShouldProcess($relDefName,"Update-ReleaseDefinition"))
		{
			$relDefFull.PSObject.Properties.Remove('createdBy');
			$relDefFull.PSObject.Properties.Remove('createdOn');
			$relDefFull.PSObject.Properties.Remove('modifiedBy');
			$relDefFull.PSObject.Properties.Remove('modifiedOn');
			Write-Output ("`t==> Updating '{0}'." -f $relDefName);
			try
			{
				$updateResult =Update-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ReleaseDefinition $relDefFull -ProjectUrl $projectUrl -AuthHeader $authHeader;
				if ($null -eq $updateResult)
				{
					Write-Output "`t==> Update failed!";
				}
				else
				{
					Write-Output "`t==> Update succeeded."
				}
			}
			catch
			{
				Write-Output ("`t==> Update-ReleaseDefinitionById threw exception: {0}"-f $_.Exception.Message);
			}
		}
	}
}
Write-Output ("Finishing {0}." -f [System.IO.Path]::GetFileNameWithoutExtension($PSCmdlet.MyInvocation.InvocationName));
