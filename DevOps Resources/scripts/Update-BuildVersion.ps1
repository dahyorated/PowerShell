<#
.Synopsis
Update the build version.

.Description
The Update-BuildVersion script updates the build version in a pipeline.

Environment Inputs:
-BUILD_SOURCEBRANCHNAME
-BUILD_DEFINITIONNAME
-SYSTEM_TEAMFOUNDATIONSERVERURI
-SYSTEM_TEAMPROJECT
-MajorMinorVersionDevelop
-MajorMinorVersionOther

Pipeline Output:
-$(build.updatebuildnumber)

The build version is derived from the contents of the versioning variable group for the build.
- The variable group is named "Versioning_$Env:BUILD_DEFINITIONNAME".
- The MajorMinorVersionDevelop and MajorMinorVersionOther are used to control when updates are needed:
-- First "develop" branch build in a new sprint;
-- First build in a release branch; and
-- First build of a hot fix.

.Parameter RepositoryName
This is the name of the repository.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Parameter MasterRepositoriesControl
This is a JSON control file containing an array of repositories that support build versioning on the master branch.

.Parameter TestingMode
If specified, the script runs for any value of $Env:BUILD_SOURCEBRANCH.

.Example
$Env:BUILD_SOURCEBRANCHNAME = 'develop';
PS C:\>$Env:BUILD_DEFINITIONNAME = 'Test CI';

PS C:\>$Env:SYSTEM_TEAMPROJECT = 'Global Tax Platform';

PS C:\>$Env:SYSTEM_TEAMFOUNDATIONSERVERURI = 'https://eyglobaltaxplatform.visualstudio.com'

This updates the build number for the 'Test - CI' in the 'develop' branch.

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
	[string]$RepositoryName = $Env:BUILD_REPOSITORY_NAME,
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = $Env:SYSTEM_ACCESSTOKEN,
	[Parameter(Mandatory=$false)]
	[string]$MasterRepositoriesControl = "UpdateBuildVersion-MasterRepositories.json",
	[switch]$TestingMode
)

Function Format-Value
{
	param(
		[string]$value
	)
	return @{
		value = "$value"
	};
}
Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
$masterRepositories = Get-Content $PSScriptRoot\$MasterRepositoriesControl | ConvertFrom-Json;
$authHeader = New-AuthorizationHeader $token;
# Prepare base URL
$orgUrl = Get-NonEmptyChoice "$Env:SYSTEM_TEAMFOUNDATIONSERVERURI" ("https://dev.azure.com/{0}" -f $Account);
Write-Verbose $orgUrl;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId;
$teamProject = Get-NonEmptyChoice "$Env:SYSTEM_TEAMPROJECT" "$ProjectName";
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$sourceBranch = $Env:BUILD_SOURCEBRANCH;
$sourceBranchName = $Env:BUILD_SOURCEBRANCHNAME;
Write-Output "BUILD_SOURCEBRANCH = $sourceBranch";
Write-Output "BUILD_SOURCEBRANCHNAME = $sourceBranchName";
# If the current build branch is a feature branch then build versioning is not used.
if (-not $TestingMode -and ($sourceBranch.IndexOf('/feature/') -ne -1))
{
	Write-Output "Versioning is not used on feature branches. Build branch is: '$sourceBranch'.";
	Exit;
}
$Build_DefinitionName = $Env:BUILD_DEFINITIONNAME;
Write-NameAndValue "BUILD_DEFINITIONNAME" $Build_DefinitionName;
Write-NameAndValue "SYSTEM_TEAMFOUNDATIONSERVERURI" $Env:SYSTEM_TEAMFOUNDATIONSERVERURI;
Write-NameAndValue "SYSTEM_TEAMPROJECT" $Env:SYSTEM_TEAMPROJECT;
# Get the current major minor version for both develop and hot fixes
$majorMinorVersionDevelop = $Env:MAJORMINORVERSIONDEVELOP;
$majorMajorMinorVersionOther = $Env:MAJORMINORVERSIONOTHER;
Write-NameAndValue "MajorMinorVersionDevelop" $majorMinorVersionDevelop;
Write-NameAndValue "MajorMinorVersionOther" $majorMajorMinorVersionOther;
if ([string]::IsNullOrWhiteSpace($majorMinorVersionDevelop) -or [string]::IsNullOrWhiteSpace($majorMajorMinorVersionOther))
{
	$errorMessage = "MajorMinorVersion Develop and/or Other are not defined.";
	Stop-ProcessError -errorMessage $errorMessage;
}
# Get the variable group name from the build name
$simpleName = $Build_DefinitionName.Replace(" ","").TrimEnd("CI").TrimEnd("-");
$groupName = "Versioning_{0}" -f $simpleName;
Write-Verbose "Retrieving '$groupName'."
$variableGroupJSON = Get-VariableGroup $groupName $tfsBaseUrl $teamProject $authHeader;
# Check if the variable group exists for this build
if ($null -eq $variableGroupJSON)
{
	$devlopVariable = Format-Value ($majorMinorVersionDevelop + ".0");
	$variableGroup = @{
		variables = @{
			Develop = $devlopVariable
			Releases = ${env:MajorMinorVersionOther};
		}
		type = "Vsts"
		name = $groupName
		description = "Versioning for $($Build_DefinitionName)"
	};
	Write-Output "Creating Variable Group Parameters:`n$($newVariableGroupJSON)";
	$variableGroupJSON = New-VariableGroup $variableGroup $tfsBaseUrl $teamProject $authHeader;
	Write-Output ("{0} VariableGroup: {1}" -f $groupName,($variableGroupJSON | ConvertTo-Json -Depth 100 -Compress));
	$variableGroupId = $variableGroupJSON.id
}
else
{
	$variableGroupId = $variableGroupJSON.id;
}
$previousDevelopBuildNumber = $variableGroupJSON.variables.Develop.value;
$previousReleases = $variableGroupJSON.variables.Releases.value;
Write-Output "variableGroupId = $variableGroupId";
$variableGroupJSON.PSObject.Properties.Remove('createdBy')
$variableGroupJSON.PSObject.Properties.Remove('createdOn')
$variableGroupJSON.PSObject.Properties.Remove('modifiedBy')
$variableGroupJSON.PSObject.Properties.Remove('modifiedOn')
$variableGroupJSON.PSObject.Properties.Remove('isShared')
#get the branch name for this which the current build is running for
$sourceBranchName = $sourceBranchName.ToLower();
if (($sourceBranchName -eq 'develop') -or (($masterRepositories -contains $RepositoryName) -and ($sourceBranchName -eq 'master'))) {
	# Incrementing the build number for the develop branch
	$BuildNumberParts = $($previousDevelopBuildNumber ) -split '\.'
	$rootBuildNumber = $BuildNumberParts[0],$BuildNumberParts[1],$BuildNumberParts[2] -join '.';
	Write-Output "rootBuildNumber: $($rootBuildNumber)";
	# Check to see if the develop major and minor semantic in the ManjoMinorVersion variable group and Versioning_<buildname> variable group is the same.
	if ($majorMinorVersionDevelop.Equals($rootBuildNumber))
	{
		# if so, increment the build number.
		$TFSRevision = [int]$BuildNumberParts[3] + 1;
	}
	else
	{
		#If not, then reset the build number to 1.
		$TFSRevision = 1;
	}
	# Update the Versioning_<buildname> just for the Develop version number
	$newDevelopBuildNumber = "$majorMinorVersionDevelop.$TFSRevision";
	$variableGroupJSON.variables.Develop.value = $newDevelopBuildNumber;
	Write-Output "##vso[build.updatebuildnumber]$newDevelopBuildNumber";
}
elseif ($sourceBranch -like '*/release/pi*')
{
	# Incrementing the build number for the release branches (includes hot fix branches)
	# Get release number
	$releaseNumber = $sourceBranchName.ToLower().Replace("pi","");
	$releases = $previousReleases | ConvertFrom-Json;
	$masterReleases = $majorMajorMinorVersionOther | ConvertFrom-Json;
	$mrl = [System.Collections.ArrayList]$masterReleases.releases;
	$mrlm =$mrl | Where-Object branch -eq $releaseNumber;
	if ($null -eq $mrlm)
	{
		Stop-ProcessError "No match for $releaseNumber in MajorMinorVersionOther."
	}
	Write-Verbose $releases;
	if ($releases.name -ne 'MajorMinorVersionOther')
	{
		$errorMessage = "'{0}' is not the correct name for the MajorMinorVersionOther variable JSON content." -f ($releases.name);
		Stop-ProcessError $errorMessage;
	}
	if ($releases.version -ne 1)
	{
		$errorMessage = "'{0}' is an unsupported version for the MajorMinorVersionOther variable JSON content." -f ($releases.version);
		Stop-ProcessError $errorMessage;
	}
	$rl =[System.Collections.ArrayList]$releases.releases;
	if ($IsVerbose)
	{
		Write-Output "Before:";
		$rl;
	}
	$rlm = $rl | Where-Object branch -eq $releaseNumber;
	if ($null -eq $rlm)
	{
		$newIndex = $rl.Add($mrlm);
		Write-Verbose $newIndex;
		$rl = $rl | Sort-Object branch -Descending;
		$rlm = $rl | Where-Object branch -eq $releaseNumber;
	}
	if ($mrlm.hotfixVersion -ne $rlm.hotfixVersion)
	{
		$rlm.hotfixVersion = $mrlm.hotfixVersion;
		$rlm.buildNumber = 0;
	}
	$rlm.buildNumber = ++($rlm.buildNumber);
	if ($IsVerbose)
	{
		Write-Output "Updated: ";
		$rlm;
	}
	$newHotfixBuildNumber = "{0}.{1}.{2}" -f $rlm.branch,$rlm.hotfixVersion,$rlm.buildNumber;
	$releases.releases = [array]$rl;
	$variableGroupJSON.variables.Releases = $releases | ConvertTo-Json -Depth 100 -Compress;
	if ($variableGroupJSON.variables.Releases.IsReadOnly)
	{
		$variableGroupJSON.variables.Releases.PSObject.Properties.Remove('IsReadOnly');
	}
	Write-Output "##vso[build.updatebuildnumber]$newHotfixBuildNumber";
}
else
{
	Write-Output "Versioning is not used on build branch: '$sourceBranch'.";
	Exit;
}
# update the Versioning_<buildname> variable group
Write-Verbose "Update Variable Group Parameters:`n$($versionJSON | ConvertTo-JSON -Depth 100 -Compress)";
$updatedVariableGroupJSON = Update-VariableGroup $variableGroupJSON $tfsBaseUrl $teamProject $authHeader;
Write-Output ("Updated Variable Group: {0}" -f ($updatedVariableGroupJSON | ConvertTo-JSON -Depth 100 -Compress));
