<#
.SYNOPSIS
Get the release definition IDs needed for tenant database and service deployments and updates the 'clientdb' database.

.DESCRIPTION
The Update-TenantReleaseDefinitionIds.ps1 script gets the release definition IDs needed for tenant database and service deployments and updates the 'clientdb' database Common.TenantedService table.
The output is:
- A list of the IDs and a T-SQL script to update the 'clientdb' database Common.TenantedService table; and
- The updated 'clientdb' database Common.TenantedService table.

.PARAMETER JsonTenantReleases
This is a JSON file containing the names of the release pipelines for tenant databases and services.

.PARAMETER StageName
This is the stage to be updated. It must be the full stage name (e.g., UAT-EUW).

.Parameter SourceBranchName
This is the leaf of the source branch (e.g., "develop" or "PI10.3").

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Example
$ENV:RELEASE_ENVIRONMENTNAME = "QAT-EUW";

PS C:\>$ENV:BUILD_SOURCEBRANCHNAME = "PI10.3";

PS C:\>Update-TenantReleaseDefinitionIds -WhatIf;

This example shows the processing that would occur in the 'clientdb' database for the QAT environment.

.Example
$ENV:RELEASE_ENVIRONMENTNAME = "QAT-EUW";

PS C:\>$ENV:BUILD_SOURCEBRANCHNAME = "PI10.3";

PS C:\>Update-TenantReleaseDefinitionIds;

This example updates all the tenant database and service entries in the 'clientdb' database for the QAT environment.

.Example
Update-TenantReleaseDefinitionIds -StageName "QAT-EUW" -SourceBranchName "PI10.3";

This example is equivalent to the previous example.
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
	[string]$SourceBranchName = $ENV:BUILD_SOURCEBRANCHNAME,
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = $ENV:SYSTEM_ACCESSTOKEN
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

if ($SourceBranchName -eq 'develop')
{
	Write-Output "No clientdb updates required for deployments for the 'develop' branch";
	Exit;
}
Write-Output ("Starting Update-TenantReleaseDefinitionIds -StageName '{0}' -SourceBranchName '{1}'" -f $StageName,$SourceBranchName);
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$queryPath = "\CTP\Release {0}" -f $SourceBranchName.TrimStart("PI");
$result = Get-AllReleaseDefinitionsByPath $queryPath $projectUrl $authHeader;
[array]$rds = $result.value;
$stage = Get-StrippedStageName $StageName;
$KeyVaultName = Get-KeyVaultNameFromStageName -StageName $StageName;
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
	$likePattern = "{0}*" -f $rdName;
	$matchingRd = $rds | Where-Object name -like $likePattern;
	$relDefId = $matchingRd.id;
	$serviceName =$rd.tenantServiceName;
	Write-Output "$($rdName): $($serviceName) = $($relDefId)";
	$sqlScript += ("UPDATE Common.TenantedService SET DatabaseMigrationReleaseId = {0} WHERE ServiceNm = '{1}';" -f $relDefId,$serviceName);
	Update-TenantedService $relDefId $serviceName;
};
$updateSql = "UPDATE Common.TenantedService SET [AppServiceReleaseId] = @RelDefId WHERE [ServiceNm] = @ServiceNm";
foreach ($rd in $tenantSvcPipelines)
{
	$rdName = $rd.pipeline;
	$likePattern = "{0}*" -f $rdName;
	$matchingRd = $rds | Where-Object name -like $likePattern;
	$relDefId = $matchingRd.id;
	$serviceName =$rd.tenantServiceName;
	Write-Output "$($rdName): $($serviceName) = $($relDefId)";
	$sqlScript += ("UPDATE Common.TenantedService SET [AppServiceReleaseId] = {0} WHERE ServiceNm = '{1}';" -f $relDefId,$serviceName);
	Update-TenantedService $relDefId $serviceName;
};
Write-Output "`nT-SQL commands used to update 'clientdb'.`n";
$sqlScript;
