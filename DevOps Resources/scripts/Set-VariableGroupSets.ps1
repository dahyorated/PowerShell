<#
.Synopsis
Set the variable group IDs in the control file to the current value of each referenced variable group.

.Description
The Set-VariableGroupSets script sets the variable group IDs in the -ControlFile control file to the current value of each referenced variable group. The control file is updated on successful completion.

.Parameter ControlFile
This is the JSON control file that defines the variable groups by stage.

.Parameter Account
This is the Azure DevOps account.

.Parameter ProjectName
This is the Azure DevOps project to search.

.Parameter Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
Set-VariableGroupSets -ControlFile C:\EYdev\devops\scripts\VariableGroupSetsRelease.json;

This sets the variable group ID for all variable groups referenced in the "C:\EYdev\devops\scripts\VariableGroupSetsRelease.json" control file.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$ControlFile = "$PSScriptRoot\VariableGroupSetsRelease.json",
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN}
)

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$header = New-AuthorizationHeader $token;
$tfsBaseUrl = (Get-DevOpsUrl -orgUrl $orgUrl -header $header -AreaId $coreAreaId).TrimEnd("/");
$control = ConvertFrom-Json -InputObject ([string](Get-Content $ControlFile));
if (($control.name -ne [System.IO.Path]::GetFileNameWithoutExtension($ControlFile)) -or ($control.version -ne 1))
{
	$errorMessage = "Control file '{0}' has incorrect name or version." -f $ControlFile.FullName;
	Stop-ProcessError -ErrorMessage $errorMessage;
}
foreach ($set in $control.sets)
{
	foreach ($group in $set.groups)
	{
		$vgName = $group.name;
		$variableGroup = Get-VariableGroup -GroupName $vgName -BaseUrl $tfsBaseUrl -TeamProject $ProjectName -AuthHeader $header;
		if ($null -eq $variableGroup)
		{
			$errorMessage = "Unknown variable group '{0}' in set '{1}'." -f $vgName,$set.name;
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		$vgId = $variableGroup.id;
		$group.id = $vgId;
	}
}
if ($PSCmdlet.ShouldProcess($ControlFile,"Update"))
{
	Write-Output ("Updating '{0}'" -f $ControlFile);
	$control | ConvertTo-Json -Depth 100 | Out-File -FilePath $ControlFile -Confirm:$false -Force -WhatIf:$false;
}
