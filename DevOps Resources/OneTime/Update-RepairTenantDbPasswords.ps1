<#
.SYNOPSIS
Repair Invalid Tenant Database Passwords Selected By ClientId & Environment

.DESCRIPTION
Script to select all Tenant Database information from keyvault, replace all invalid characters in the database passwords
and update secrets in the keyvault and database users in the targeted sql databases.
Note: This script is intended to run in a console manually and not through a pipeline

.PARAMETER ClientId
Client Id whose db passwords should be updated.

.PARAMETER StageName
Environment where client resides.

.Example
.\Update-RepairTenantDbPasswords.ps1 -ClientId 1740 -StageName "PRD-EUW" -dbBaseNames @("boardwalk","reporting")

#>
   [CmdletBinding()]
   param (
	   [Parameter(Mandatory=$true)]
	   [int]$ClientId,
	   [Parameter(Mandatory=$true)]
	   [ValidatePattern('(DEV|QAT|UAT|DMO|PRF|STG|PRD)-(EUW|USE)')]
	   [string]$StageName,
	   [Parameter(Mandatory=$false)]
	   [string[]]$dbBaseNames = @("apaccitadj","boardwalk","bwapods","datawarehouse","decision","document","entityservice","eyoods","inforequest","ingestion","notification","reporting","taxfactimportexport")
   )

#functions
function Update-DbUserPassword
{
	Param
	(
		[string]$dbUser,
		[string]$dbAdminPass,
		[string]$newPass,
		[string]$oldPass,
		[string]$connString
	)

	#build connection string using master user and password
	$dbMasterUser = "dbWSS";
	$connMaster = $connString;
	$connMaster = $connMaster.Replace($dbUser, $dbMasterUser);
	$connMaster = $connMaster.Replace($oldPass, $dbAdminPass);

	#build command
	$sqlTemplate = "ALTER USER {0} WITH PASSWORD = '{1}' OLD_PASSWORD = '{2}'";
	$sql = $sqlTemplate -f $dbUser, $newPass, $oldPass;

	#connect, execute query statement, close connection
	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection;
	$sqlConnection.ConnectionString = $connMaster;
	$sqlConnection.Open();
	$cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
	$sqlResult = $cmd.ExecuteNonQuery() | Out-Null; 
	$sqlConnection.Close();
	return $sqlResult;
}

function Get-RepairedPassword
{
	Param
	(
		[string]$currVal
	)

	$newVal = $currVal;
	$newVal = $newVal.Replace('=', 'a');
	$newVal = $newVal.Replace(',', 'b');
	return $newVal;
}

function Get-SqlServerFromConnectionString
{
	Param
	(
		[string]$conn
	)

	$conn = $conn.ToUpper();
	$sServer = "???";

	#split SQL paramameters and find server parameter
	$sqlParams = $conn -split ";";
	$filteredParams = $sqlParams | Where-Object {$_ -like 'SERVER=*'};

	#remove unneeded character, split apart segments and return server name (segment 0)
	$tmpConn = $filteredParams.ToString();
	$tmpConn = $tmpConn.Replace("SERVER=TCP:", "");
	$serverSegments = $tmpConn -split "\.";
	return $serverSegments[0];
}

# Parameter Arg: for local debugging 
#   [int] $ClientId = 43;
#   [string] $StageName = "UAT-EUW";
#   [string[]] $dbBaseNames = @("apaccitadj","boardwalk","bwapods","datawarehouse","decision","document","entityservice","eyoods","inforequest","ingestion","notification","reporting","taxfactimportexport");   


#list of possible tenant databases
[string]$env = $StageName;

#Confirm You want to proceed
Write-Host "";
$inputAnswer =  Read-Host -Prompt "Retrieve/Repair relevant keyvault tenant secrets and SQL passwords for client #$ClientId in $env, Continue (yes, no)?";

if ($inputAnswer -ne 'yes')
{
	Write-Host "Script aborted per user response";
	exit;
}
Write-Host "Processing request...";
Write-Host " ";

# import modules
Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;

# get keyvault resource name & object
$kv = Get-KeyVaultNameFromStageName -StageName $env;
$KvObj = Get-AzKeyVault -VaultName $kv

#build out clientId & keyvault key patterns
$sClientId = $ClientId.ToString().PadLeft(5, '0');
$connectionTemplate = "connectionstring-{0}{1}db";
$dbUserTemplate = "{0}{1}dbuser";
$sqlAdminPassTemplate = "{0}-sqlTenantAdminPass";


#for each database, build out custom secrets object that is add to our working list
$secretsList = New-Object System.Collections.ArrayList
foreach ($baseName in $dbBaseNames)
{
	#dbuser: get current user password. If secret does not exist, we assume database does not exist and we move on to next database in list 
	$dbUserKey = $dbUserTemplate -f $baseName, $sClientId;
	$dbUserSecret = (Get-AzKeyVaultSecret -VaultName $kv -Name $dbUserKey).SecretValueText;
	if ($null -eq $dbUserSecret){
		continue;
	}

	#connection string; get current secret
	$connKey = $connectionTemplate -f $baseName, $sClientId;
	$connSecret = (Get-AzKeyVaultSecret -VaultName $kv -Name $connKey).SecretValueText;

	#get sql server admin password
	$serverName = Get-SqlServerFromConnectionString -conn $connSecret; 
	$serverAdminPassKey = $sqlAdminPassTemplate -f $serverName;
	$serverAdminPassSecret = (Get-AzKeyVaultSecret -VaultName $kv -Name $serverAdminPassKey).SecretValueText;

	#assign new secrets values
	$dbUserSecretNew = Get-RepairedPassword -currVal $dbUserSecret;

	#debug Write-Host -ForegroundColor Yellow "Replacing '$dbUserSecret' with '$dbUserSecretNew'";
	$connSecretNew = $connSecret.Replace($dbUserSecret,$dbUserSecretNew);
	#debug Write-Host -ForegroundColor Yellow "New connection is '$connSecretNew'";
	#debug Write-Host "---";

	$secretsItem = New-Object System.Object;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "dbName" -Value $baseName;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "serverAdminPassKey" -Value $serverAdminPassKey;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "serverAdminPassSecret" -Value $serverAdminPassSecret;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "dbUserKey" -Value $dbUserKey;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "dbUserSecret" -Value $dbUserSecret;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "dbUserSecretNew" -Value $dbUserSecretNew;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "connKey" -Value $connKey;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "connSecret" -Value $connSecret;
	$secretsItem | Add-Member -MemberType NoteProperty -Name "connSecretNew" -Value $connSecretNew;
	$secretsList.Add($secretsItem) | Out-Null;
}

foreach ($item in $secretsList)
{
	$databaseName = $item."dbName";

	# if current & repaired secrets are the same, skip as there is nothing to update
	if ($item."dbUserSecret" -ne $item."dbUserSecretNew")
	{
		#update sql database
		Update-DbUserPassword -dbUser $item."dbUserKey" -dbAdminPass $item."serverAdminPassSecret" -newPass $item."dbUserSecretNew" -oldPass $item."dbUserSecret" -connString $item."connSecret"; 

		#update 'connection-*' secret
		$dbConnectionKey = $item."connKey";
		$dbConnectSecretNew = $item."connSecretNew";
		$SecretdbConnectionNew = ConvertTo-SecureString -String $dbConnectSecretNew -AsPlainText -Force;
		Set-AzKeyVaultSecret -VaultName $kv -Name $dbConnectionKey -SecretValue $SecretdbConnectionNew;
	
		#update 'dbuser' secret
		$dbUserKey = $item."dbUserKey";
		$dbUserSecretNew = $item."dbUserSecretNew";
		$SecretdbUserNew = ConvertTo-SecureString -String $dbUserSecretNew -AsPlainText -Force;
		Set-AzKeyVaultSecret -VaultName $kv -Name $dbUserKey -SecretValue $SecretdbUserNew;
		Write-Host -ForegroundColor Green "$databaseName invalid password updated";
	}
	else 
	{        
		Write-Host -ForegroundColor Yellow "$databaseName not updated, current password is valid";      
	}

}

$exit

