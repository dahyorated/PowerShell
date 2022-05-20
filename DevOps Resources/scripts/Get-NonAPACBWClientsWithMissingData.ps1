<#
.SYNOPSIS
Iterate through all non-APAC BW Clients and run a SQL Script to Determine if they have missing data

.DESCRIPTION
1) get client routing - for each client
2)		check if there's an app service for boardwalk (as opposed to the APAC version)
3)		create a connection string
4)		run the sql
5) print output of all the results

.PARAMETER AuthServiceURL
Auth Service for Primary Site

.PARAMETER $ClientServiceURL
Client Service for Primary Site

.PARAMETER keyVault
Keyvault on the Primary Site

.Example

.\Get-NonAPACBWClientsWithMissingData.ps1 -authServiceURL "https://userservice-dev.sbp.eyclienthubd.com" -clientServiceURL "https://euwdgtp005wap0w.azurewebsites.net"  `
	-keyVault "EUWDGTP005AKV01"  
}

#>
[CmdletBinding()]
param (
	[Parameter(Mandatory = $True)]
	[string] $AuthServiceURL,
	[Parameter(Mandatory = $True)]
	[string] $ClientServiceURL,
	[Parameter(Mandatory = $True)]
	[string]$keyVault
)

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

$output = [ordered]  @{};

#get the client configs
$clientConfigs = Get-ClientConfiguration -AuthService $AuthServiceURL   -ClientService $ClientServiceURL  -KeyVault  $keyVault

#iterate thrugh cients
foreach ($tenant in $clientConfigs) {
	Write-Verbose $("Processing Client {0}" -f $clientId);
	$clientId = $tenant.clientId;
	$boardwalkService = $tenant.clientServiceConfigurations | where {$_.resourceTypeId -eq 3 -and $_.service -eq 'boardwalk'};
	if ($boardwalkService -eq $null) {
		continue;
	}

	$ods = $tenant.databases | where {$_.service -eq "dataservice" };
	$connString = "Server={0};Database={1};User ID={2};Password={3}" -f $ods.server, $ods.database, $ods.username, $ods.password;

	$SQL = " declare @cnttbl table
(
    tblname nvarchar(50),
    reccnt int
)
insert into @cnttbl (tblname, reccnt) select 'TaxYears', count(*) from Core.TaxYears;
insert into @cnttbl (tblname, reccnt) select 'TaxPeriods', count(*) from Core.TaxYears;
insert into @cnttbl (tblname, reccnt) select 'Client', count(*) from Core.Client;
insert into @cnttbl (tblname, reccnt) select 'Country', count(*) from Core.Country;
insert into @cnttbl (tblname, reccnt) select 'eyServices', count(*) from Core.EYServices;
insert into @cnttbl (tblname, reccnt) select 'EyServiceCountry', count(*) from Core.EYServiceCountry
insert into @cnttbl (tblname, reccnt) select 'TaxEntity', count(*) from tem.TaxEntity;


If (select count(*) from @cnttbl where reccnt = 0) > 0
begin
    select 'Bad' 
end
else
begin
    select 'Good'
end"
	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    
		try {
			$sqlConnection.ConnectionString = $connString
			$sqlConnection.Open();

			$cmd = new-object System.Data.SqlClient.SqlCommand($sql, $sqlConnection);
			$sqlResult = $cmd.ExecuteScalar();


		$output.Add(  $clientId , @{$tenant.client.name = $sqlResult});
		$sqlConnection.Close();

			
		}
		Catch {
			Throw $_
		}
	}

	Write-Output '"ClientID","ClientName","Status"';
	foreach ($out in $output.GetEnumerator())
	{
		$clientId = $out.Name;
		$val = $out.Value;
		[string]$name = $val.Keys[0];
		[string]$result = $val.Values[0];

		Write-Output $("`"{0}`",`"{1}`",`"{2}`"" -f $clientId, $name, $result);
	}
