[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)]
	[string]$Subscription = 'EY-CTSBP-NON-PROD-TAX-GTP TENANT-01-39721502',
	[Parameter(Mandatory=$false)]
	[string]$GroupName = 'GT-WEU-GTP-TENANT-PERF-RSG',
	[Parameter(Mandatory=$false)]
	[string]$Server = 'EUWFGTP001SQL01',
	[Parameter(Mandatory=$false)]
	[string]$DbNamePrefix = 'entityservice',
	[Parameter(Mandatory=$false)]
	[datetime]$RestoreTime = '2020-03-31T09:25:00Z',
	[Parameter(Mandatory=$false)]
	[int[]]$ClientIds = @(1,2,3,4,5,6,7,8,9,10)
)
Import-Module $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
Set-AzContext -SubscriptionObject (Get-AzSubscription -SubscriptionName $Subscription);
$timeStamp = $RestoreTime.ToUniversalTime().ToString('yyyy-MM-ddThh-mmZ');
$clientIdCount = $ClientIds.Count;
for ($i = 0; $i -lt $clientIdCount; $i++)
{
	$clientId = $ClientIds[$i];
	$client = $clientId.ToString().PadLeft(5,'0')
	$dbName ="{0}{1}db" -f $DbNamePrefix,$client;
	$restoreDbName ="{0}{1}db_{2}" -f $DbNamePrefix,$client,$timeStamp;
	Write-Output ("Restoring {0} to {1}" -f $dbName,$restoreDbName);
	$Database = Get-AzSqlDatabase -ResourceGroupName $groupName -ServerName $Server -DatabaseName $dbName;
	Restore-AzSqlDatabase `
		-FromPointInTimeBackup `
		-PointInTime $RestoreTime `
		-ResourceGroupName $Database.ResourceGroupName `
		-ServerName $Database.ServerName `
		-TargetDatabaseName $restoreDbName `
		-ResourceId $Database.ResourceID `
		-ElasticPoolName $Database.ElasticPoolName
	;
}
