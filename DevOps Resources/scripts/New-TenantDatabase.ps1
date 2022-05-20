<#
.Synopsis
Create a new tenant database for specific client and update Client DB with the required information.

.Description
The New-TenantDatabase.ps1 script creates a new tenant database for specific client using the parameters provided in -AppSvcDbFullPathname and updates Client DB with the required information.

.Parameter AppSvcDbFullPathname
This is the pathname (relative or full) of the JSON file that provides all of the information needed to create the database.

n.b. "environment" in the JOSN file must be one of: 'Development', 'QA', 'UAT', 'PERF', 'DEMO', 'Staging', or 'Production'.

.Parameter SkipDatabaseCreate
If specified, the creation of the database is skipped. The Client DB updates are still performed.

.Example
New-TenantDatabase.ps1 -AppSvcDbFullPathname .\PaymentDb-C00004-DEV-EUW.json

This would create a new tenant database using the contents of the ".\PaymentDb-C00004-DEV-EUW.json" file as the controlling parameters.
#>
[CmdletBinding(SupportsShouldProcess)]
Param(
	[Parameter(Mandatory=$True,ValueFromPipeline=$True,HelpMessage="JSON file containing parameters")]
	[ValidateScript({
		if( -Not ($_ | Test-Path) )
		{
			throw "Parameter file does not exist"
		}
		return $true;
	})]
	[string]$AppSvcDbFullPathname,
	[Parameter(Mandatory=$false)]
	[string]$keyVault = 'EUWDGTP005AKV01',
	[switch]$SkipDatabaseCreate
)

Function Save-ParametersInFile
{
	<#
	.Synopsis
	Save parameters in a file.

	.Description
	The Save-ParametersInFile functions save a serialized copy of -parametersJson in the -parameterFile file.
	#>
	param(
		[System.IO.FileInfo]$parameterFile,
		$parametersJson
	)
	Write-Verbose $parametersJson;
	$parametersJson | ConvertTo-Json -Depth 100 | Out-File -FilePath $parameterFile -Force;
}

Function New-Database
{
	[CmdLetBinding(SupportsShouldProcess)]
	param()
	if ($SkipDatabaseCreate)
	{
		return $parametersJson;
	}
	if (-not $PSCmdlet.ShouldProcess("$($serviceName) database for client $($clientId)"))
	{
		return $parametersJson;
	}
	$deploymentId = "GTP{0}" -f ([string]$clientId).PadLeft(3,'0');
	$creatDbParms = @{
		component = "create-sqlDb"
		extra_vars = @{
			var_deploy_to = "TENANT"
			var_environment = $environment
			var_location = $location
			var_deploymentId = $deploymentId
			var_dbName = @($dbName)
			var_dbTags = @("$($serviceName) database for client $($clientId)")
			var_dbSize = 10
			var_skuName = "S1"
			var_sqlbackuplongtermretentionmonthlymonths = "6"
			var_sqlbackuplongtermretentionweeklyweeks = "6"
			var_sqlbackuplongtermretentionyearlyyears = "6"
			var_sqlbackupshorttermretentiondays = "14"
			var_weekofyear = 10
			}
	};
	$global:createDatabaseBody = $creatDbParms | ConvertTo-Json -Depth 100 -Compress;
	Write-Verbose $global:createDatabaseBody;
	$global:createDatabaseResponse = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json"  -Body $createDatabaseBody;
	Write-Verbose $createDatabaseResponse;
	$jobId = $createDatabaseResponse.msg.jobid;
	$parametersJson.results.databaseJobId = $jobId;
	$parametersJson.results.databaseName = @($dbName);
	Save-ParametersInFile $AppSvcDbJson $parametersJson;
	$global:jobStatusAppSvcDatabaseMsg = Wait-JobCompletion $jobId -SleepIntervalInSeconds 30 -MaxWaitInSeconds 900 -noExit;
	Write-Verbose ($jobStatusAppSvcDatabaseMsg | ConvertTo-Json -Depth 100 -Compress);
	if (-not [string]::IsNullOrWhiteSpace($jobStatusAppSvcDatabaseMsg.status) -and ($jobStatusAppSvcDatabaseMsg.status.ToLower() -eq 'failed'))
	{
		$parametersJson | Add-Member -MemberType NoteProperty -Name error -Value $jobStatusAppSvcDatabaseMsg;
		Save-ParametersInFile $AppSvcDbJson $parametersJson;
		Exit;
	}
	$parametersJson.results.sqlServerName = $jobStatusAppSvcDatabaseMsg.sqlServerName;
	$parametersJson.results.keyVaultName = $jobStatusAppSvcDatabaseMsg.keyVaultName;
	$parametersJson.results.resourceGroup = $jobStatusAppSvcDatabaseMsg.resourceGroup;
	Save-ParametersInFile $AppSvcDbJson $parametersJson;
	return $parametersJson;
}

Function IsNotValidAnsibleEnvironment
{
	param(
		[string]$environment
	)
	$environments = @('Development', 'QA', 'UAT', 'PERF', 'DEMO', 'Staging', 'Production');
	return $environments -notcontains $environment;
}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
if ($AppSvcDbFullPathname.StartsWith('.\'))
{
	$AppSvcDbJson = Join-Path $PWD $AppSvcDbFullPathname.TrimStart('.\');
}
elseif ($AppSvcDbFullPathname.StartsWith('..\'))
{
	$AppSvcDbJson = Join-Path $PWD $AppSvcDbFullPathname;
}
else
{
	$AppSvcDbJson = $AppSvcDbFullPathname;
}
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($AppSvcDbJson);
$fileNameParts = $fileName -split '-';
if ($fileNameParts.Count -ne 4)
{
	$errorMesage = "Filename '{0}' has {1} parts; 4 are required. Format is <<Database Name>>-<<Client Id>>-<<Stage Name>>" -f $fileName,$fileNameParts.Count;
	Stop-ProcessError $errorMesage;
}
$isDr = $fileNameParts[3] -eq 'USE';
if ($isDr)
{
	Write-Output "Creating AppSvc DR Database using '$AppSvcDbJson'. No updates to Client DB.";
}
else
{
	Write-Output "Creating AppSvc Database using '$AppSvcDbJson'.";
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$uri = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
try
{
	Write-Verbose "AppSvcDbJson: $AppSvcDbJson";
	$parametersJson = Get-Content $AppSvcDbJson | ConvertFrom-Json;
}
catch
{
	Write-Output "Badly formed JSON file '$AppSvcDbJson'."
	Write-Output $_;
	Exit;
}
Write-Verbose ($parametersJson | ConvertTo-Json -Depth 100 -Compress);
$parameters = $parametersJson.parameters;
$environment = $parameters.environment;
$location = $parameters.location;
if (IsNotValidAnsibleEnvironment $environment)
{
	$errorMesage = "'{0}' is not a valid Ansible environment." -f $environment;
	Stop-ProcessError -errorMessage $errorMesage;
}
$serviceName = $parameters.serviceName;
$clientId = $parameters.clientId;
if ($null -eq $parametersJson.results)
{
	#add property and skeleton object
	$results = @{
		databaseJobId = 0
		sqlServerName = ''
		resourceGroup = ''
		keyVaultName = ''
		databaseName = @()
	};
	$parametersJson | Add-Member -MemberType NoteProperty -Name results -Value $results;
	Save-ParametersInFile $AppSvcDbJson $parametersJson;
}
$DBNamePrefix = ($serviceName.ToLower() -split " ")[0];
$dbName = "{0}{1}db" -f $DBNamePrefix,([string]$clientId).PadLeft(5,'0');
$parametersJson = New-Database;
if ($isDr)
{
	Write-Output "DR Database: No Client DB database updates required.";
	Exit;
}
if (-not [string]::IsNullOrWhiteSpace($parametersJson.results.keyVaultName))
{
	$keyVault = $parametersJson.results.keyVaultName;
}
Write-Output "Opening up key vault '$($keyVault)' to get client DB connection";
$clientDbConnectionSecret = Get-AzKeyVaultSecret -VaultName $keyVault -Name 'connectionstring-clientdb';
$clientDbConnectionString = $clientDbConnectionSecret.SecretValueText;
Write-Verbose "clientDbConnectionString: '$($clientDbConnectionString)'";
# determine the Client ID
$connection = new-object System.Data.SqlClient.SQLConnection($clientDbConnectionString);
$connection.Open();
$selectCommand = "select ClientConfigId from Common.ClientConfiguration where ClientId = '$clientId'";
$command = new-object System.Data.SqlClient.SqlCommand($selectCommand, $connection);
$ClientConfigId = $command.ExecuteScalar();
Write-Output ("Client Config Id is: {0}" -f $ClientConfigId );
$selectCommand = "SELECT COUNT([TenantedServiceId]) FROM [Common].[TenantedService] WHERE [DatabaseNm] = '{0}';" -f $DBNamePrefix;
$command = new-object System.Data.SqlClient.SqlCommand($selectCommand, $connection);
$serviceCount = $command.ExecuteScalar();
if ($serviceCount -ne 1)
{
	Write-Output ("'{0}' is not defined in the [Common].[TenantedService] table." -f $DBNamePrefix);
	Exit 1;
}
$TenantSqlServer = $parametersJson.results.sqlServerName;
$dbUser = '{0}user' -f $dbName;
$currentUtcTime = (Get-Date).ToUniversalTime();
$dbServiceName = $serviceName.ToLower().Replace(" ","");
Write-Output "TenantSqlServer: $($TenantSqlServer), dbUser: $($dbUser), dbServiceName: $($dbServiceName)";
$insert_SQL = "
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
	IF NOT EXISTS (	SELECT * FROM [Common].[ClientServiceConfiguration]
				WITH (UPDLOCK)
				WHERE [ClientConfigId] = @ClientConfigId
						AND [ResourceTypeId] = @ResourceTypeid
						AND [Service] = @Service)
		BEGIN
			-- then we want to insert
			INSERT INTO [Common].[ClientServiceConfiguration]
			([ClientConfigId],[Service],[ResourceTypeId],[AccountName],[ResourceURL]
				,[Container],[Database],[Server],[Username],[IsProvisioned]
				,[IsRequired],[IsFailed],[ErrorMessage],[ErrorCd],[GTPRecordStatusId]
				,[IsDeleted],[CreatedUser],[CreatedDtm],[UpdatedUser],[UpdatedDtm])
			VALUES
			(@ClientConfigId,@Service,@ResourceTypeId,@AccountName,@ResourceURL
				,@Container,@Database,@Server,@Username,@IsProvisioned
				,@IsRequired,@IsFailed,@ErrorMessage,@ErrorCd,@GTPRecordStatusId
				,@IsDeleted,@CreatedUser,@CreatedDtm,@UpdatedUser,@UpdatedDtm);
		END
COMMIT;
";
$insertDB_Command = new-object System.Data.SqlClient.SqlCommand($insert_SQL, $connection);
$global:dbParams = New-Object System.Collections.ArrayList;
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@ClientConfigId", $ClientConfigId));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@Service", $dbServiceName));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@Database", $dbName));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@Server", $TenantSqlServer));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@Username", $dbUser));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@ResourceTypeId", 2));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@AccountName", [DBNull]::Value));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@ResourceURL", [DBNull]::Value));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@Container", [DBNull]::Value));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@IsProvisioned", 1));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@IsRequired", 1));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@IsFailed", 0));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@ErrorMessage", [DBNull]::Value));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@ErrorCd", 0));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@GTPRecordStatusId", 1));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@IsDeleted", 0));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@CreatedUser", "gtp.devops@ey.com"));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@CreatedDtm", $currentUtcTime));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@UpdatedUser", "gtp.devops@ey.com"));
$newIndex = $dbParams.Add($insertDB_Command.Parameters.AddWithValue("@UpdatedDtm", $currentUtcTime));
Write-Verbose $newIndex;
Write-Output "Inserting into [Common].[ClientServiceConfigurationId]";
$insertDB_Result = $insertDB_Command.ExecuteScalar();
if ($null -eq $insertDB_Result)
{
	Write-Output "Inserting into [Common].[ClientServiceConfigurationId] failed!"
}
Write-Output "Updated $insertDB_Result rows";
