<#
.Synopsis
Reads a CSV file containing BW App Serivice names and checks routing to see if it's used

.Description
Reads a CSV with column "Name" as an app service name - will query clientdb routing tables checking provisioned,delete flags etc

.Parameter CsvFile
Path to CSV File

.Parameter env
Standard environment abbrev defaults to PRD 

.Example
Confirm-BWAppServiceDelete.ps1 -CsvFile "C:\eydev\devops\scripts\Tests\Data\AppServices_Report_ToDelete.csv" -env "prd";


#>
[CmdletBinding()]
param (
		[Parameter(Mandatory = $True)]
		[string] $CsvFile,
		[Parameter(Mandatory = $false)]
		[string]$env = "prd"
)

Import-Module -Name C:\eydev\devops\scripts\DevOps -Force -Verbose:$false;
$kv = Get-KeyVaultNameFromStageName -StageName $env;

$connString = (Get-AzKeyVaultSecret -VaultName $kv -Name 'connectionstring-clientdb').SecretValueText;

[hashtable]$report = @{};
$appServiceFile = import-csv $CsvFile;
$appserviceNames = [System.Collections.ArrayList]@();
foreach ($appServiceLine in $appServiceFile)
{
	$name = $appServiceLine.("Name");
	if ($report.ContainsKey($name)) {
		continue;
	}
	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection;
	$sqlConnection.ConnectionString = $connString;
	$sqlConnection.Open();

	$sql = "
SELECT CSC.ClientServiceConfigurationId FROM Common.ClientServiceConfiguration csc 
INNER JOIN common.ClientConfiguration cc ON cc.ClientConfigId = csc.ClientConfigId
INNER JOIN common.ClientProfile cp ON cp.ClientId = cc.ClientId and cp.CurrentRecord = 1
WHERE csc.AccountName = '{0}'
AND cp.IsDeleted = 0
AND cp.GTPRecordStatusId = 1
AND csc.IsProvisioned = 1
AND csc.IsDeleted = 0
	" -f $name;
	$cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
	$reader = $cmd.ExecuteReader();
	$exists = $reader.Read();
	if ($exists)
	{
		$value = "Used in GTP";
	}
	else
	{
		$value = "Not used in GTP";
	}
	$report.Add($name, $value);
	$reader.Close();
	$sqlConnection.Close();
}

$report;
