<#
.SYNOPSIS
Get the release definition IDs needed for tenant database deployments and updates the 'clientdb' database.

.DESCRIPTION
The Get-TenantDbReleaseDefinitionIds.ps1 script gets the release definition IDs needed for tenant database deployments and updates the 'clientdb' database.
The output is a list of the IDs and a T-SQL script to update the 'clientdb' database.

.PARAMETER KeyVaultName
This is the key vault for the current environment.

.PARAMETER JsonReleaseDefinitionStatus
This is the current release definition status JSON file.

.PARAMETER JsonTenantReleases
This is a JSON file containing the names of the release pipelines for tenant databases and services.

.PARAMETER StageName
This is the stage to be updated. It can be the full stage name (e.g., UAT-EUW) or just eh environment (e.g., UAT).

.Example
Get-TenantDbReleaseDefinitionIds -KeyVaultName EUWQGTP007AKV01 -StageName 'QAT-EUW' -WhatIf;

This example shows the processing that would occur in the 'clientdb' database for the QAT environment.

.Example
Get-TenantDbReleaseDefinitionIds -KeyVaultName EUWQGTP007AKV01 -StageName 'QAT-EUW';

This example updates all the tenant database and service entries in the 'clientdb' database for the QAT environment.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
	[Parameter(Mandatory=$False)]
	[string]$KeyVaultName = "EUWUGTP014AKV01", # Default is for UAT
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonReleaseDefinitionStatus = "$pwd\ReleaseDefinitionStatus.json",
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
	[string]$StageName = 'UAT-EUW'
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
	[CmdletBinding(ConfirmImpact='None',SupportsShouldProcess=$true)]
	param(
		$relDefId,
		$serviceName
	)
	if (-not $PSCmdlet.ShouldProcess($serviceName))
	{
		return;
	}
	$serviceNameParameterValue = "{0}" -f $serviceName;
	$updateCommand = New-Object System.Data.SqlClient.SqlCommand($updateSql, $connection);
	$result = $updateCommand.Parameters.AddWithValue("@RelDefId", $relDefId);
	$result = $updateCommand.Parameters.AddWithValue("@ServiceNm", $serviceNameParameterValue);
	$result = $updateCommand.ExecuteNonQuery();
	Write-Output "Updated '$serviceNameParameterValue', effected rows = $result.";
}

Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
$stage = Get-StrippedStageName $StageName;
$rdPipelinesToGet = Get-Content $JsonTenantReleases | ConvertFrom-Json;
[array]$rdDbNamesToGet = $rdPipelinesToGet | Where-Object type -eq 'DB';
[array]$rdSvcNamesToGet = $rdPipelinesToGet | Where-Object type -eq 'SVC';
$rds = Get-Content $JsonReleaseDefinitionStatus | ConvertFrom-Json;
$sqlScript = @();
$sqlScript += "USE clientdb;"
if (-not $WhatIfPreference)
{
	Connect-ClientDb;
}
$updateSql = "UPDATE Common.TenantedService SET [DatabaseMigrationReleaseId] = @RelDefId WHERE [ServiceNm] = @ServiceNm";
foreach ($rd in $rdDbNamesToGet)
{
	$rdName = $rd.pipeline;
	$matchingRd = $rds | Where-Object definitionName -eq $rdName;
	$relDefId = $matchingRd.$stage.DefId;
	[string]$databaseName = $matchingRd.databaseName;
	$serviceName =$databaseName.TrimEnd('db');
	Write-Output "$($rdName): $($databaseName) = $($relDefId)";
	$sqlScript += ("UPDATE Common.TenantedService SET DatabaseMigrationReleaseId = {0} WHERE ServiceNm = '{1}';" -f $relDefId,$serviceName);
	Update-TenantedService $relDefId $serviceName;
};
$updateSql = "UPDATE Common.TenantedService SET [AppServiceReleaseId] = @RelDefId WHERE [ServiceNm] = @ServiceNm";
foreach ($rd in $rdSvcNamesToGet)
{
	$rdName = $rd.pipeline;
	$matchingRd = $rds | Where-Object definitionName -eq $rdName;
	$relDefId = $matchingRd.$stage.DefId;
	$serviceName =$matchingRd.$stage.AppServiceName;
	Write-Output "$($rdName): $($serviceName) = $($relDefId)";
	$sqlScript += ("UPDATE Common.TenantedService SET [AppServiceReleaseId] = {0} WHERE ServiceNm = '{1}';" -f $relDefId,$serviceName);
	Update-TenantedService $relDefId $serviceName;
};
Write-Output "`nT-SQL commands used to update 'clientdb'.`n";
$sqlScript;
