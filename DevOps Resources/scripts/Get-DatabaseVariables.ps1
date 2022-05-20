<#
.SYNOPSIS
Gets the database variables needed for deployment.

.DESCRIPTION
This gets the database variables for -DatabaseName and -StageName needed for deployment. -KeyVault contains the password for the database user. All variables are returned as DevOps pipeline variable.
- dbUser (SQL Server user name for -DatabaseName)
- TargetPassword (SQL Server password for TargetUser)
- dbServer (SQL Server URL for -DatabaseName)

.PARAMETER DatabaseName
This is the name of the database.

.PARAMETER StageName
This is the stage in which the -DatabaseName is being deployed.

.PARAMETER KeyVault
This is the key vault containing the password for the -DatabaseName user.

.EXAMPLE
Get-DatabaseVariables.ps1 -DatbaseName 'userservicedb' -StageName 'DEV-EUW' -KeyVault 'EUWDGTP005AKV01'

This gets the database user, database password, and database server for the 'userservicedb' database.

.EXAMPLE 
Get-DatabaseVariables.ps1

This is equivalent to Example 1.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False,Position=1)]
	[string]$DatabaseName = 'userservicedb',
	[Parameter(Mandatory=$False,Position=2)]
	[string]$StageName = 'DEV-EUW',
	[Parameter(Mandatory=$False,Position=3)]
	[string]$KeyVault = 'EUWDGTP005AKV01'
)
Push-Location "$PSScriptRoot";
$jsonFile = ".\Databases.json";
$databases = (Get-Content $jsonFile | ConvertFrom-Json);
Write-Verbose "Loaded $($databases.Count) databases."
$database = $databases | Where-Object Database -eq $DatabaseName;
if ($database -eq $null)
{
	throw "$($DatabaseName) is not in '$($jsonFile)'.";
}
$stage = $database.Stages | Where-Object StageName -eq $StageName;
if ($stage -eq $null)
{
	throw "$StageName is not in '$($jsonFile)' for the '$($DatabaseName)' database.";
}
$targetUser = $database.UserName;
$targetUrl = $stage.ServerUrl;
Write-Verbose "User: $targetUser, URL: $targetUrl";
Write-Host "##vso[task.setvariable variable=dbUser]$targetUser";
Write-Host "##vso[task.setvariable variable=dbServer]$targetUrl";
.\Get-SecretsIntoPipelineVariables.ps1 -KeyVaultName "$KeyVault" -SecretNames @($($database.UserName));
Pop-Location;
