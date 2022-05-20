<#
.Synopsis
Update Releases in all versioning variable groups with the current value of the Develop variable.

.Description
The Update-VariableGroupsReleasesFromDevelop script updates Releases in all versioning variable groups with the current value of the Develop variable if the value is for the -Release branch.

.PARAMETER Release
This is the release.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Team
This is a team for which the sprints are defined.

.Parameter VariableGroups
This is the list of variable group to process. If none are specified, then all versioning variable groups are processed.

.Parameter NoUpdate
If specified this skips updating the variable group. This supports testing.

.Example
Update-VariableGroupsReleasesFromDevelop -Release 9.4;

This updates Releases in all variable groups where the Develop variable is for release '9.4'.

.Example
Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test') -UseTest;

This updates a single variable group, 'Versioning_Test', if the Develop variable is for release '9.4'.

#>
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release,
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
	[switch]$NoUpdate
)

Function Get-VariableGroupsAll
{
	param(
		[string]$BaseUrl,
		[string]$TeamProject,
		[HashTable]$AuthHeader
	)
	$resultGet = Get-AllVariableGroup -GroupName '*' -BaseUrl $BaseUrl -TeamProject $TeamProject -AuthHeader $AuthHeader;
	$vgsCount = $resultGet.Count;
	[array]$vgs = $resultGet.value;
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

Function Update-ReleasesVariable
{
	param(
		[PSCustomObject]$vg,
		[string]$otherMaster
	)
	$vgv = $vg.variables;
	$vgv.Develop.PSObject.Properties.Remove('isSecret');
	$vgv.Releases.PSObject.Properties.Remove('isSecret');
	$vgv.Releases.PSObject.Properties.Remove('isReadOnly');
	$releases = $vgv.Releases.value | ConvertFrom-Json;
	Write-Output ("Develop variable value: {0}" -f $vgv.Develop.value);
	$developParts = $vgv.Develop.value -split '\.';
	$developBranch = $developParts[0],$developParts[1] -join '.';
	if ($Release -ne $developBranch)
	{
		return $False;
	}
	[int]$hotfixVersion = [int]$developParts[2];
	[int]$buildNumber = [int]$developParts[3];
	Write-Output ("Develop: {0}.{1}.{2}" -f $developBranch,$hotfixVersion,$buildNumber);
	$match = $releases.releases | Where-Object {$developBranch -eq $_.branch};
	if ($null -ne $match)
	{
		$match.hotfixVersion = $hotfixVersion;
		$match.buildNumber = $buildNumber;
	}
	else
	{
		$newBranch = [PSCustomObject]@{
			branch = $developBranch
			hotfixVersion = $hotfixVersion
			buildNumber = $buildNumber
		};
		$rl = [System.Collections.ArrayList]$releases.releases;
		$addIndex = $rl.Add($newBranch);
		$rl = $rl | Sort-Object branch -Descending
		$releases.releases = [array]$rl;
		Write-Verbose ("Added releases[{0}], branch: {1}" -f $addIndex,$newBranch.branch);
	}
	$vgv.Releases.value = $releases | ConvertTo-Json -Depth 100 -Compress;
	return $True;
}

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "Starting Update-VariableGroupsReleasesFromDevelop";
$authHeader = New-AuthorizationHeader ${env:SYSTEM_ACCESSTOKEN};
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "${env:SYSTEM_TEAMFOUNDATIONSERVERURI}" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = (Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId).TrimEnd("/");
$teamProject = Get-NonEmptyChoice "${env:SYSTEM_TEAMPROJECT}" "$ProjectName";
Write-Verbose "SYSTEM_TEAMFOUNDATIONSERVERURI = '$tfsBaseUrl'";
Write-Verbose "SYSTEM_TEAMPROJECT = '$teamProject'";
[array]$all = Get-VariableGroupsAll -BaseUrl $tfsBaseUrl -TeamProject $teamProject -AuthHeader $authHeader;
Write-Output ("Processing {0} variable groups." -f $all.Count);
$all | ForEach-Object {
	$vg = $_;
	$vgId = $vg.id;
	$vgName = $vg.name;
	Write-Output ("Processing variable group '{0}'." -f $vg.name);
	$isModified = Update-ReleasesVariable $vg $otherMaster;
	if ($isModified)
	{
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
			Write-Output ("Updated Variable Group '{0}'" -f $vg.name);
			Write-AsJson -CustomObject $vg -Compress;
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
				Write-Output "Update-VariableGroup failed!"
			}
		}
	}
};
Write-Output "Finishing Update-VariableGroupsReleasesFromDevelop";
