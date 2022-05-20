<#
.Synopsis
Copy configuration service data to the deployment repository and folder.

.Description
The Copy-ConfigurationToDeploymentFolder script copies configuration service data to the deployment repository and folder.

.Parameter StageName
This is the standard name for the stage being processed.

.Parameter Environment
This is the standard name for the targeted environment.

.Parameter Source
This is the folder containing all of the YAML files. It is assumed to have no sub-directories.

.Parameter Destination
This is the URI for the destination Azure DevOps git repository.

.Parameter LocalRepoFolder
This is the full pathname of the folder in which the Configuration repository will be cloned.

.Parameter AuthorEmail
This is the user's email for the git operations

.Parameter AuthorName
This is the user's name for the git operations.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
Copy-ConfigurationToDeploymentFolder -StageName QAT-EUW -Environment euwqa -Source ".../_CI/drop" -Destination <<repo>>

This copies the YAML configuration files that are for all environments and that are for the "euwqa" environment from artifact drop folder to the "euwqa" folder in the <<repo>> Azure DevOps git repository.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact ='None')]
param(
	[Parameter(Mandatory=$true)]
	[string]$StageName,
	[Parameter(Mandatory=$true)]
	[string]$Environment,
	[Parameter(Mandatory=$true)]
	[ValidateScript({
		if(!($_ | Split-Path | Test-Path) )
		{
			throw "Folder for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$Source,
	[Parameter(Mandatory=$true)]
	[string]$Destination,
	[Parameter(Mandatory=$false)]
	[string]$LocalRepoFolder = $ENV:AGENT_RELEASEDIRECTORY,
	[Parameter(Mandatory=$false)]
	[string]$AuthorEmail = $ENV:RELEASE_DEPLOYMENT_REQUESTEDFOREMAIL,
	[Parameter(Mandatory=$false)]
	[string]$AuthorName = $ENV:RELEASE_DEPLOYMENT_REQUESTEDFOR,
	[Parameter(Mandatory=$false)]
	[string]$SubscriptionId = $ENV:SUBSCRIPTIONID,
	[Parameter(Mandatory=$false)]
	[string]$ResourceGroup = $ENV:RESOURCEGROUP,
	[string]$Token = $Env:SYSTEM_ACCESSTOKEN
)

Function Invoke-VerboseCommand {
param(
	[Parameter(Mandatory=$true)]
	[ScriptBlock]$Command,
	[Parameter(Mandatory=$false)]
	[string] $StderrPrefix = "",
	[Parameter(Mandatory=$false)]
	[int[]]$AllowedExitCodes = @(0,128)
)
	$Script = $Command.ToString();
	$Captures = Select-String '\$(\w+)' -Input $Script -AllMatches;
	ForEach ($Capture in $Captures.Matches)
	{
		$Variable = $Capture.Groups[1].Value;
		$Value = Get-Variable -Name $Variable -ValueOnly;
		$Script = $Script.Replace("`$$($Variable)", $Value);
	}
	Write-Output $Script.Trim();
	If ($null -ne $script:ErrorActionPreference)
	{
		$backupErrorActionPreference = $script:ErrorActionPreference;
	} ElseIf ($null -ne $ErrorActionPreference)
	{
		$backupErrorActionPreference = $ErrorActionPreference;
	}
	$script:ErrorActionPreference = "Continue";
	try
	{
		& $Command 2>&1 | ForEach-Object -Process `
		{
			if ($_ -is [System.Management.Automation.ErrorRecord])
			{
				"$StderrPrefix$_";
			}
			else
			{
				"$_";
			}
		}
		if ($AllowedExitCodes -notcontains $LASTEXITCODE)
		{
			throw "Execution failed with exit code $LASTEXITCODE";
		}
	}
	finally
	{
		$script:ErrorActionPreference = $backupErrorActionPreference;
	}
}

Function Start-Git
{
	git version;
	git lfs version;
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$branch = 'master';
$likePattern = "*.{0}.yaml" -f $Environment;
Write-Output "Starting Copy-ConfigurationToDeploymentFolder";
Write-Output ("Processing Stage {0}" -f $StageName);
$allFiles = Get-ChildItem $Source -Filter '*.yaml';
Write-Output ("Found {0} YAML files." -f $allFiles.Count);
Write-Output ("Removing all content from '{0}'." -f $LocalRepoFolder);
Get-ChildItem $LocalRepoFolder -Recurse -Force | ForEach-Object {
	Remove-Item $_.FullName -Force -Recurse;
};
Start-Git;
git config --global user.email "$AuthorEmail";
git config --global user.name "$AuthorName";
git config --global -l;
try
{
	git -c http.extraheader="Authorization: bearer $ENV:SYSTEM_ACCESSTOKEN" clone "$Destination" $LocalRepoFolder;
}
catch
{
	$message = $_.Exception.Message;
	Stop-ProcessError $message;
}
Push-Location $LocalRepoFolder;
Write-Output ("Executing git operations on behalf of '{0} <{1}>'." -f $AuthorName,$AuthorEmail);
$localEnvironmentFolder = [System.IO.Path]::Combine($LocalRepoFolder,$Environment);
if (-not (Test-Path $localEnvironmentFolder))
{
	New-Item -ItemType Directory -Path $localEnvironmentFolder;
}
Write-Output ("Updating '{0}'." -f $localEnvironmentFolder);
$sourceFiles = [System.Collections.ArrayList]@();
foreach ($nextFile in $allFiles)
{
	$i = $sourceFiles.Add($nextFile.Name);
}
Write-Verbose ("Added {0} source file to `$sourceFiles." -f ($i+1));
$matchPattern = ".*\.(use|euw)(dev|qa|uat|dmo|prf|prd)\.yaml";
[array]$globalFiles = $allFiles | Where-Object name -notmatch $matchPattern;
Write-Output ("Found {0} non-environment files." -f $globalFiles.Count);
ForEach ($globalFile in $globalFiles) {
	Write-Output ("Copying '{0}' to '{1}/{2}'" -f $globalFile.name,$LocalRepoFolder,$Environment);
	Copy-Item $globalFile.FullName -Destination $localEnvironmentFolder;
};
[array]$envFiles = $allFiles | Where-Object name -like $likePattern;
Write-Output ("Found {0} environment files." -f $envFiles.Count);
ForEach ($envFile in $envFiles) {
	Write-Output ("Copying '{0}' to '{1}/{2}'" -f $envFile.name,$LocalRepoFolder,$Environment);
	Copy-Item $envFile.FullName -Destination $localEnvironmentFolder;
};
Get-ChildItem $localEnvironmentFolder -Filter '*.yaml' | ForEach-Object {
	$finalEnvFile = $_.Name
	if ($sourceFiles -notcontains $finalEnvFile)
	{
		$pathSpec = "{0}/{1}" -f $Environment,$finalEnvFile;
		git rm $pathSpec;
	}
};
git add --all .;
git status;
$message = "Configuration server data updates for '{0}'." -f $Environment;
git commit -am "$message";
git -c http.extraheader="Authorization: bearer $ENV:SYSTEM_ACCESSTOKEN" push;
Pop-Location;
Write-Output "Finishing Copy-ConfigurationToDeploymentFolder";
