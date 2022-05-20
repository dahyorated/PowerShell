<#
.SYNOPSIS
Updates the release definition ID needed for tenant deployments in the 'clientdb' database.

.DESCRIPTION
The Update-TenantReleaseDefinitionId script updates the release definition ID needed for tenant deployments in the 'clientdb' database.
- The script output is the ID and a T-SQL script to update the 'clientdb' database.
- The script also updates the 'clientdb' database.

.PARAMETER KeyVaultName
This is the key vault for the current environment.

.PARAMETER JsonTenantReleases
This is a JSON file containing the names of the release pipelines for tenant databases and services.

.PARAMETER StageName
This is the stage to be updated. It can be the full stage name (e.g., UAT-EUW) or just the environment (e.g., UAT).

.Paramter ReleaseDefinitionId
This is the ID for the release definition for the release being processed.

.Example
Get-TenantDbReleaseDefinitionIds -KeyVaultName EUWQGTP007AKV01 -StageName 'QAT-EUW' -WhatIf;

This example shows the processing that would occur in the 'clientdb' database for the QAT environment.

.Example
Get-TenantDbReleaseDefinitionIds -KeyVaultName EUWQGTP007AKV01 -StageName 'QAT-EUW';

This example updates all the tenant database and service entries in the 'clientdb' database for the QAT environment.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonTenantReleases = "$PSScriptRoot\TenantReleases.json",
	[Parameter(Mandatory=$false)]
	[string]$StageName = $ENV:RELEASE_ENVIRONMENTNAME,
	[Parameter(Mandatory=$false)]
	[string]$ReleaseDefinitionId = $ENV:RELEASE_DEFINITIONID,
	[Parameter(Mandatory=$false)]
	[string]$ReleaseDefinitionName = $ENV:RELEASE_DEFINITIONNAME
)

Function Connect-ClientDb
{
	$clientDbConnectionSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'connectionstring-clientdb';
	$clientDbConnectionString = $clientDbConnectionSecret.SecretValueText;
	$script:connection = new-object System.Data.SqlClient.SQLConnection($clientDbConnectionString);
	$connection.Open();
}

Function Update-TenantedService
{
	[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None')]
	param(
		$relDefId,
		$serviceName
	)
	$serviceNameParameterValue = "{0}" -f $serviceName;
	$updateCommand = New-Object System.Data.SqlClient.SqlCommand($updateSql, $connection);
	$result = $updateCommand.Parameters.AddWithValue("@RelDefId", $relDefId);
	$result = $updateCommand.Parameters.AddWithValue("@ServiceNm", $serviceNameParameterValue);
	if ($PSCmdlet.ShouldProcess($serviceName))
	{
		$result = $updateCommand.ExecuteNonQuery();
		Write-Output "Updated '$serviceNameParameterValue', effected rows = $result.";
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$KeyVaultName = Get-KeyVaultNameFromStageName -StageName $StageName;
$stage = Get-StrippedStageName $StageName;
$tenantPipelines = Get-Content $JsonTenantReleases | ConvertFrom-Json;
[array]$tenantDbPipelines = $tenantPipelines | Where-Object type -eq 'DB';
[array]$tenantSvcPipelines = $tenantPipelines | Where-Object type -eq 'SVC';
$sqlScript = @();
$sqlScript += "USE clientdb;"
if (-not $WhatIfPreference)
{
	Connect-ClientDb;
}
$updateSql = "UPDATE Common.TenantedService SET [DatabaseMigrationReleaseId] = @RelDefId WHERE [ServiceNm] = @ServiceNm";
foreach ($rd in $tenantDbPipelines)
{
	$rdName = $rd.pipeline;
	if (-not $ReleaseDefinitionName.StartsWith($rdName))
	{
		continue;
	}
	$serviceName =$rd.tenantServiceName;
	Write-Output ("{0}: {1} = {2}" -f $rdName,$serviceName,$ReleaseDefinitionId);
	$sqlScript += ("UPDATE Common.TenantedService SET DatabaseMigrationReleaseId = {0} WHERE ServiceNm = '{1}';" -f $ReleaseDefinitionId,$serviceName);
	Update-TenantedService $ReleaseDefinitionId $serviceName;
};
$updateSql = "UPDATE Common.TenantedService SET [AppServiceReleaseId] = @RelDefId WHERE [ServiceNm] = @ServiceNm";
foreach ($rd in $tenantSvcPipelines)
{
	$rdName = $rd.pipeline;
	if (-not $ReleaseDefinitionName.StartsWith($rdName))
	{
		continue;
	}
	$serviceName =$rd.tenantServiceName;
	Write-Output ("{0}: {1} = {2}" -f $rdName,$serviceName,$ReleaseDefinitionId);
	$sqlScript += ("UPDATE Common.TenantedService SET [AppServiceReleaseId] = {0} WHERE ServiceNm = '{1}';" -f $ReleaseDefinitionId,$serviceName);
	Update-TenantedService $ReleaseDefinitionId $serviceName;
};
Write-Output "`nT-SQL commands used to update 'clientdb'.`n";
$sqlScript;
