<#
.Synopsis
Update tenant databases using ready roll migrations.

.Description
The Update-ReadyRollMigrations script updates tenant databases using -MigrationScript ready roll migrations.

.Parameter MigrationScript
This is the ready-roll migration script.

.Parameter ServiceName
This is the name of the tenant service.

.Parameter AuthService
This is the URL of the user authentication service.

.Parameter ClientService
This is the URL of the Client Service.

.Parameter ServiceID
This is the service ID.

.Parameter ServiceAuthSecret
If provided, this is used for the service call. If "NA", the secret will be retrieved from -KeyVaultName.

.Parameter KeyVaultName
This is the key vault name. This is primarily used in non-pipeline testing.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param (
	[Parameter(Mandatory=$true, Position=0)]
	[String]$MigrationScript,
	[Parameter(Mandatory=$true, Position=1)]
	[String]$ServiceName,
	[Parameter(Mandatory=$true, Position=2)]
	[String]$AuthService,
	[Parameter(Mandatory=$true, Position=3)]
	[String]$ClientService,
	[Parameter(Mandatory=$true, Position=4)]
	[String]$ServiceID,
	[Parameter(Mandatory=$true, Position=5)]
	[String]$ServiceAuthSecret,
	[Parameter(Mandatory=$false)]
	[string]$KeyVaultName
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
if ($ServiceAuthSecret -eq 'NA')
{
	$ServiceAuthSecret = '';
}
$migrationScriptFilename = [System.IO.Path]::GetFileNameWithoutExtension($MigrationScript);
$BwServiceName = $($env:BwServiceName)
$OdsServiceName = $($env:OdsServiceName)
$ApacBwServiceName = $($env:ApacBwServiceName); #bwapods
$ApacOdsServiceName = $($env:ApacOdsServiceName); #apacclientconfig
Write-NameAndValue "env:BwServiceName" $BwServiceName;
Write-NameAndValue "env:OdsServiceName" $OdsServiceName;
Write-NameAndValue "ServiceName" $ServiceName;
Write-NameAndValue "AuthService" $AuthService;
Write-NameAndValue "ClientService" $ClientService;
Write-NameAndValue "ServiceID" $ServiceID;
Write-NameAndValue "MigrationScript" $MigrationScript;
# Get SQLCMD path
$sqlCmd = $null
$paths = @(
	"C:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe",
	"C:\Program Files\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe",
	"C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe",
	"C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\sqlcmd.exe",
	"C:\Program Files (x86)\Microsoft SQL Server\150\Tools\Binn\sqlcmd.exe",
	"C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"
)
foreach ($path in $paths)
{
	if ((Test-Path $path) -eq $true)
	{
		$sqlCmd = $path;
		Write-Output "SQLCMD located in $sqlCmd";
		break;
	}
}
if ($null -eq $sqlCmd)
{
	$errorMessage = "Could not find 'SQLCMD.exe'.";
	Stop-ProcessError -errorMessage $errorMessage;
}
# Add sqlcmd.exe to the path so ReadyRoll can find it.
$sqlCmdPath = Split-Path -Path $sqlCmd -Parent;
$env:Path = "$($env:Path);$sqlCmdPath";
[array]$clientConfigs = Get-ClientConfiguration -ServiceAuthSecret $ServiceAuthSecret -AuthService $AuthService -ClientService $ClientService -KeyVault $KeyVaultName;
$startTime = Get-Date;
$clientCount = $clientConfigs.Count;
$currentClient = 0;
foreach ($tenant in $clientConfigs)
{
	$currentClient++;
	$tenantId = $tenant.clientId.ToString().PadLeft(6,"0");
	Write-Output ("==> Processing client '{0}' ({1} of {2})." -f $tenantId,$currentClient,$clientCount);
	foreach ($databaseConfig in $tenant.databases)
	{
		#provision these variables in to memory; reset for every run
		$OdsUserName = $OdsPassWord = $OdsServer = $OdsDatabase = "";
		$BwUserName = $BwPassWord = $BwServer = $BwDatabase = "";
		if (($null -ne $BwServiceName ) -and ($null -ne $OdsServiceName ) )
		{
			if ($databaseConfig.service.Equals($BwServiceName)) {
				foreach( $dbc in $tenant.databases)
				{
					if ($dbc.service.Equals($OdsServiceName))
					{
						Write-Output "...populating ODS Variables"
						$OdsUserName = $dbc.username.ToString();
						$OdsPassWord = $dbc.password.ToString();
						$OdsServer = $dbc.server.ToString();
						$OdsDatabase = $dbc.database.ToString();
					}
				}
			}
			if ($databaseConfig.service.Equals($OdsServiceName) )
			{
				foreach( $dbc in $tenant.databases)
				{
					if ($dbc.service.Equals($BwServiceName))
					{
						Write-Output "...populating BW Variables"
						$BwUserName = $dbc.username.ToString();
						$BwPassWord = $dbc.password.ToString();
						$BwServer = $dbc.server.ToString();
						$BwDatabase = $dbc.database.ToString();
					}
				}
			}
		}
		$ApodsUserName = $ApodsPassWord = $ApodsDatabase = $ApodsServer = "";
		$ApacBwUserName = $ApacBwPassWord = $ApacBwDatabase = $ApacBwServer = "";
		if (($ApacBwServiceName -ne $null ) -and ($ApacOdsServiceName -ne $null))
		{
			if ($databaseConfig.service.Equals($ApacBwServiceName))
			{
				foreach( $dbc in $tenant.databases)
				{
					if ($dbc.service.Equals($ApacOdsServiceName))
					{
						Write-Output "...populating ODS Variables"
						$ApodsUserName = $dbc.username.ToString();
						$ApodsPassWord = $dbc.password.ToString();
						$ApodsDatabase = $dbc.server.ToString();
						$ApodsServer = $dbc.database.ToString();
					}
				}
			}
			if ($databaseConfig.service.Equals($ApacOdsServiceName))
			{
				foreach( $dbc in $tenant.databases)
				{
					if ($dbc.service.Equals($ApacBwServiceName))
					{
						Write-Output "...populating BW Variables"
						$ApacBwUserName = $dbc.username.ToString();
						$ApacBwPassWord = $dbc.password.ToString();
						$ApacBwDatabase = $dbc.server.ToString();
						$ApacBwServer = $dbc.database.ToString();
					}
				}
			}
		}
		if (-not $ServiceName.Equals($databaseConfig.service, [System.StringComparison]::OrdinalIgnoreCase))
		{
			continue;
		}
		# Skip DBs that haven't been provisioned yet or are in a failed state.
		Write-NameAndValue "IsProvisioned" $databaseConfig.isProvisioned;
		Write-NameAndValue "IsFailed" $databaseConfig.isFailed;
		if ((-not $databaseConfig.isProvisioned) -or $databaseConfig.isFailed)
		{
			continue;
		}
		Write-Output "Migrating $($databaseConfig.database) database for $ServiceName on $($databaseConfig.server) for tenant $($databaseConfig.clientId)...";
		# Set ReadyRoll deployment variables.
		$DatabaseServer = $databaseConfig.server;
		$DatabaseName = $databaseConfig.database;
		$UseWindowsAuth = $false;
		$DatabaseUserName = $databaseConfig.username;
		$DatabasePassword = $databaseConfig.password;
		$ClientId = $databaseConfig.clientId.ToString();
		Write-Debug "Executing migration script..."
		$message = "& $MigrationScript | Out-Default";
		if ($PSCmdlet.ShouldProcess($DatabaseName,$migrationScriptFilename))
		{
			Write-Output $message;
			& $MigrationScript | Out-Default;
		}
	}
	$endTime = Get-Date;
	$elapsedHours = ($endTime-$startTime).TotalHours;
	$remainingClients = $clientCount-$currentClient;
	$estimatedRemainingHours = ($elapsedHours/$currentClient)*$remainingClients;
	$estimatedEndTime = $endTime.AddHours($estimatedRemainingHours);
	$endTimeFormatted = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($estimatedEndTime, 'Eastern Standard Time')).ToString("hh:mm:ss ExT");
	Write-Output ("==> Processed client '{0}' ({1} of {2}). Estimated completion time: {3}." -f $tenantId,$currentClient,$clientCount,$endTimeFormatted);
}
