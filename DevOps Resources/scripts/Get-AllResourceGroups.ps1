<#
.Synopsis
Collect information on all GTP resource groups.

.Description
The Get-AllResourceGroups script collects information on all GTP resource groups.

.Parameter ResourceGroupFile
This is the absolute or relative pathname of the JSON file that will contain information about all of the resources.

.Parameter SkipRefresh
If specified, the content of the -ResourceGroupFile JSON file is used without being refreshed.

.Parameter NoExcel
If specified, no Excel spreadsheet is produced.

#>
[CmdletBinding()]
param(
	[string]$ResourceGroupFile = "$PWD\ResourceGroups.json",
	[switch]$SkipRefresh,
	[switch]$NoExcel
)
$locations = @('westeurope','eastus');
if ($SkipRefresh)
{
	[System.Collections.ArrayList]$AllResourceGroups = Get-Content $ResourceGroupFile | ConvertFrom-Json;
}
else
{
	[System.Collections.ArrayList]$AllResourceGroups = @();
	$subscriptions = Get-AzSubscription | Select-Object name,id | Sort-Object name;
	foreach ($subscription in $subscriptions)
	{
		Set-AzContext -SubscriptionName $subscription.name;
		[Array]$resourceGroups = Get-AzResourceGroup |
			Where-Object { ($_.ResourceGroupName -like 'GT*') -and ($locations -contains $_.Location)} |
			Select-Object ResourceGroupName,Location;
		$isTenant = ($subscription.name -like '*tenant*') -or ($subscription.name -like '*capella*');
		foreach ($resourceGroup in $resourceGroups)
		{
			$match = [regex]::Match($resourceGroup.ResourceGroupName.ToUpper(),"-(DEV|QA|UAT|PERF|DEMO|STG|PROD)-");
			if ($match.Groups.Count -gt 1)
			{
				$stage = $match.Groups[1].Captures[0].Value;
			}
			else
			{
				$stage ="NA";
			}
			$newResourceGroup = [PSCustomObject]@{
				Subscription = $subscription.name
				ResourceGroup = $resourceGroup.ResourceGroupName
				Location = $resourceGroup.Location
				IsTenant = $isTenant
				Stage = $stage
			};
			$AllResourceGroups.Add($newResourceGroup);
		}
	}
	$AllResourceGroups | ConvertTo-Json -Depth 100 | Out-File -FilePath "$ResourceGroupFile";
}
if ($NoExcel)
{
	Write-Output "No Excel file created";
}
else
{
	$xlsxFile = [System.IO.Path]::ChangeExtension($ResourceGroupFile,"xlsx");
	Write-Output "Excel spreadsheet will be saved in '$($xlsxFile)'.";
	Remove-Item $xlsxFile -ErrorAction Ignore;
	$excelParams = @{
		Path = "$xlsxFile"
		Show = $true
		TableName = "ResourceGroups"
		AutoSize = $true
		FreezeTopRowFirstColumn = $true
	};
	Import-Module ImportExcel;
	$AllResourceGroups | Export-Excel @excelParams;
}
