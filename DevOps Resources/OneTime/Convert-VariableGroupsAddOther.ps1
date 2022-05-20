<#
.Synopsis
Update all versioning variable groups with the MajorMinorVersionOther variable and the initial content.

.Description
The Convert-VariableGroupsAddOther script updates all versioning variable groups with the MajorMinorVersionOther variable and the initial content based on the value in -MasterGroupName.

.PARAMETER MasterGroupName
This is the name of the variable group containing the master template of the major/minor version.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Team
This is a team for which the sprints are defined.

.Parameter VariableGroups
This is the list of variable group to process. If none are specified, then all versioning variable groups are processed.

.Parameter UseTest
If specified, this forces the script to use the test version of -MasterGroupName (i.e., the -MasterGroupName with a "Test" suffix).

.Parameter NoUpdate
If specified this skips updating the variable group. This supports testing.

.Example
Convert-VariableGroupsAddOther;

This updates all variable groups using 'MajorMinorVersion' to define the content.

.Example
Convert-VariableGroupsAddOther -VariableGroups @('Versioning_Test') -UseTest;

This updates a single variable group, 'Versioning_Test', using 'MajorMinorVersionTest' to define the content.

#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)]
	[string]$MasterGroupName = "MajorMinorVersion",
	[Parameter(Mandatory=$False)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$False)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$False)]
	[string]$Team = "DevOps",
	[Parameter(Mandatory=$False)]
	[string[]]$VariableGroups = @(),
	[switch]$UseTest,
	[switch]$NoUpdate
)

Class Release
{
	[string]$branch
	[int]$hotfixVersion
	[int]$buildNumber
}

Function Get-VariableGroupsAll
{
	$vgs = ConvertFrom-Json ([string](az pipelines variable-group list --group-name Versioning_* --top 1000 --organization $org --project $project));
	$vgsCount = $vgs.Count;
	$result = New-Object System.Collections.ArrayList;
	for ($i = 0; $i -lt $vgsCount; $i++)
	{
		$vg = $vgs[$i];
		if (($VariableGroups.Count -eq 0) -or
			(($VariableGroups.Count -ne 0) -and ($VariableGroups -contains $vg.name)))
		{
			$addIndex = $result.Add($vgs[$i]);
			Write-Verbose ("Adding {0}[{1}]." -f $vg.name,$addIndex);
		}
	}
	return $result;
}

Function Set-ReleasesVariable
{
	param(
		[PSCustomObject]$vg,
		[string]$otherMaster
	)
	$other = $otherMaster | ConvertFrom-Json;
	$vgv = $vg.variables;
	$vgv.Develop.PSObject.Properties.Remove('isSecret');
	$vgv.Hotfix.PSObject.Properties.Remove('isSecret');
	$releases = $vgv.Releases;
	if ($null -eq $releases)
	{
		Write-Output "Adding new variable 'Releases'";
		$propertyValue = [PSCustomObject]@{
			value = ''
		};
		$vgv | Add-Member -NotePropertyName 'Releases'-NotePropertyValue $propertyValue;
	}
	else
	{
		$vgv.Releases.PSObject.Properties.Remove('isSecret');
	}
	Write-Output ("Hotfix variable value: {0}" -f $vgv.Hotfix.value);
	$hotfixParts = $vgv.Hotfix.value -split '\.';
	[string]$release = $null;
	[int]$hotfixVersion = 0;
	[int]$buildNumber = 0;
	if ($hotfixParts.Count -eq 3)
	{
		$release = $hotfixParts[0],$hotfixParts[1] -join '.';
		$hotfixVersion = 1;
		$buildNumber = [int]$hotfixParts[2];
	}
	elseif ($hotfixParts.Count -eq 4)
	{
		$release = $hotfixParts[0],$hotfixParts[1] -join '.';
		$hotfixVersion = [int]$hotfixParts[2];
		$buildNumber = [int]$hotfixParts[3];
	}
	else
	{
		$release = $null;
		$hotfixVersion = 0;
		$buildNumber = 0;
	}
	Write-Output ("Hotfix: {0}.{1}.{2}" -f $release,$hotfixVersion,$buildNumber);
	$newOtherReleases = [System.Collections.ArrayList]$other.releases;
	$match = $newOtherReleases | Where-Object {$release -eq $_.branch};
	if ($null -ne $match)
	{
		$match.hotfixVersion = $hotfixVersion;
		$match.buildNumber = $buildNumber;
	}
	else
	{
		$newBranch = [Release]@{
			branch = $release
			hotfixVersion = $hotfixVersion
			buildNumber = $buildNumber
		};
		$addIndex = $newOtherReleases.Add($newBranch);
		Write-Verbose ("Added newOtherReleases[{0}], branch: {1}" -f $addIndex,$newBranch.branch);
	}
	$other.releases = $newOtherReleases | Sort-Object branch -Descending;
	$vgv.Releases.value = $other | ConvertTo-Json -Depth 100 -Compress;
}

Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Starting Convert-VariableGroupsAddOther";
if ($UseTest)
{
	$MasterGroupName = "{0}Test" -f $MasterGroupName;
}
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = (Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId).TrimEnd("/");
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
Write-Output ("Getting variable group master from '{0}'." -f $MasterGroupName);
$master = Get-VariableGroup $MasterGroupName $tfsBaseUrl $ProjectName $authHeader;
$otherMaster = $master[0].variables.MajorMinorVersionOther.value;
$allDraft = Get-VariableGroupsAll;
if ($allDraft.Count -lt 2)
{
	$all = New-Object System.Collections.ArrayList;
	$addIndex = $all.Add($allDraft);
}
else
{
	$all = $allDraft;
}
Write-Output ("Processing {0} variable groups." -f $all.Count);
$all | ForEach-Object {
	$vg = $_;
	$vgId = $vg.id;
	$vgName = $vg.name;
	Write-Output ("Processing variable group '{0}'." -f $vg.name);
	Set-ReleasesVariable $vg $otherMaster;
	$vg.PSObject.Properties.Remove('createdBy');
	$vg.PSObject.Properties.Remove('createdOn');
	$vg.PSObject.Properties.Remove('modifiedBy');
	$vg.PSObject.Properties.Remove('modifiedOn');
	$vg.PSObject.Properties.Remove('isShared');
	$vg.PSObject.Properties.Remove('description');
	$vg.PSObject.Properties.Remove('variableGroupProjectReferences');
	$vg.PSObject.Properties.Remove('providerData');
	if ($NoUpdate)
	{
		$variableGroupJson = $vg | ConvertTo-Json -Depth 100 -Compress;
		Write-Output ("Update JSON: {0}" -f $variableGroupJson);
	}
	else
	{
		Write-Output ("Updating '{0}({1})'." -f $vgName,$vgId);
		$updatedVariableGroup = Update-VariableGroup $vg $tfsBaseUrl $ProjectName $authHeader;
		if ($null -ne $updatedVariableGroup)
		{
			Write-Verbose ($updatedVariableGroup | ConvertTo-Json -Depth 100 -Compress);
		}
		else
		{
			Write-Outout "Update-VariableGroup failed!"
		}
	}
};
Write-Output "Finishing Convert-VariableGroupsAddOther";
