<#
.SYNOPSIS
Get the deployed service versions for an environment.

.DESCRIPTION
This gets the deployed service versions for the -StageName environment.

.PARAMETER StageName
This is the environment portion of a standard stage name (e.g., 'DEV' for 'DEV-EUW').

.PARAMETER JsonReleaseDefinitionStatus
This is the current release definition status file.

.PARAMETER Refresh
If provided, the content of -JsonReleaseDefinitionStatus is refreshed using "Get-ReleaseStatus".

.Example
Get-DeployedVersions -StageName DEV;

This get the deployed versions for the DEV-EUW environment and creates the "Deployed Resource - DEV.xlsx" spreadsheet.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$True)]
	[ValidateSet('DEV','QAT','UAT','PRF','DMO','STG','PRD','SHR')]
	[string]$StageName,
	[Parameter(Mandatory=$false)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf))
		{
			throw "File for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonReleaseDefinitionStatus = "$pwd\ReleaseDefinitionStatus.json",
	[switch]$Refresh
)

class StageGroup {
	[string]$SubscriptionName
	[string]$ResourceGroupName
}

class DeployedResource {
	[string]$ServiceName
	[string]$ServerName
	[string]$Version
	[string]$ReleaseName
	[string]$ReleaseId
	[string]$BuildName
	[string]$BuildId
	[string]$Error
}

Function Get-ReleaseDefitnionStatusFromJson
{
	if (-not (Test-Path -Path $JsonReleaseDefinitionStatus -PathType Leaf))
	{
		Write-Output "Creating '$($JsonReleaseDefinitionStatus)'.";
		Get-ReleaseStatus -Force -NoExcel;
	}
	elseif ($Refresh)
	{
		Write-Output "Refreshing '$($JsonReleaseDefinitionStatus)'.";
		Get-ReleaseStatus -NoExcel;
	}
	return Get-Content -Path $JsonReleaseDefinitionStatus | ConvertFrom-Json;
}

Function Get-StageGroup
{
	param(
		[string]$stageName
	)
	$resourceGroup = [StageGroup]::new();
	switch ($stageName)
	{
		'DEV'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-DEV-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502';
		}
		'QAT'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-QA-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502';
		}
		'UAT'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-UAT-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502';
		}
		'PRF'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-PERF-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502';
		}
		'DMO'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-DMO-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-PROD-TAX-GTP_DEMO_CORE-01-39861197';
		}
		'STG'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-STG-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-PROD-TAX-GTP CORE-01-39721502';
		}
		'PRD'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-PROD-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-PROD-TAX-GTP CORE-01-39721502';
		}
		'SHR'
		{
			$resourceGroup.ResourceGroupName = 'GT-WEU-GTP-CORE-SHR-RSG';
			$resourceGroup.SubscriptionName = 'EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502';
		}
		default
		{
			$errorMessage = "Unsupported stage name '$stageName'";
			Stop-ProcessError $errorMessage;
		}
	};
	return $resourceGroup;
}

Function Get-MatchingStatus
{
	param(
		[DeployedResource]$deployedResource,
		[string]$stageName,
		[string]$serviceName
	)
	Write-Verbose "Searching stage '$stageName' for '$serviceName'.";
	if ($stageName -eq 'SHR')
	{
		$stageName = 'DEV';
	}
	$matchingRelStatuses = $rdStatuses | Where-Object { $_.$stageName.AppServiceName -eq $serviceName };
	if ($null -ne $matchingRelStatuses)
	{
		$matchingStage = $matchingRelStatuses.$stageName;
		$deployedResource.ReleaseName = $matchingStage.ReleaseName;
		$deployedResource.ReleaseId = $matchingStage.ReleaseId;
		$deployedResource.BuildName = $matchingStage.BuildName;
		$deployedResource.BuildId = $matchingStage.BuildId;
	}
	else
	{
		Write-Output "No matching status for stage '$stageName' for '$serviceName'.";
		$deployedResource.ReleaseName = '';
		$deployedResource.ReleaseId = 0;
		$deployedResource.BuildName = '';
		$deployedResource.BuildId = 0;
	}
	return $deployedResource;
}

Function ExportTo-Excel
{
	$xslxFile = "Deployed Resource - {0}.xlsx" -f $StageName;
	$excelParams = @{
		Path = $xslxFile
		Show = $false
		TableName = "DeployedResources"
		WorkSheetName = $StageName
		AutoSize = $true
		FreezeTopRow = $true
	};
	Import-Module ImportExcel;
	Remove-Item -Path $xslxFile -ErrorAction Ignore;
	$count = $deployedResources.Count;
	$range = "D2:D{0}" -f ($count+1);
	$noMatch = New-ConditionalText -ConditionalType NotContainsText -ConditionalTextColor White -BackgroundColor Red -Range $range;
	$excelPackage = $deployedResources |
		#Select-Object ServiceName,ServerName,Version,ReleaseName,ReleaseId,BuildName,BuildId,Error |
		Select-Object -Property ServiceName,ServerName,Version,ReleaseName,ReleaseId,BuildName,BuildId,@{Name="Error"; Expression = {$_.Error.Substring(0,[math]::Min(50,$_.Error.Length))}} |
		Sort-Object ServiceName |
		Export-Excel @excelParams -ConditionalText $noMatch -PassThru;
	$sheet = $excelPackage.Workbook.WorkSheets["$StageName"];
	$sheet.Name = "{0} as of {1}" -f $StageName,((Get-Date).ToString("yyyy-MM-dd HH:mm"));
	Close-ExcelPackage -ExcelPackage $excelPackage -Show;
}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
$urlFormat = "https://{0}.azurewebsites.net/";
$global:rdStatuses = Get-ReleaseDefitnionStatusFromJson;
$currentContext = Get-AzContext;
$resourceGroup = Get-StageGroup $StageName;
$tempContext = Set-AzContext -Subscription "$($resourceGroup.SubscriptionName)";
$AppServices = Get-AzResource -ResourceGroupName "$($resourceGroup.ResourceGroupName)" |
	Where-Object ResourceType -eq 'Microsoft.Web/sites' |
	Select-Object -Property ResourceName,@{Name="RolePurpose"; Expression = {$_.Tags.ROLE_PURPOSE.Trim()}};
Write-Output "Processing $($AppServices.Count) app services.";
$deployedResources = New-Object System.Collections.ArrayList;
if ($isVerbose)
{
	Write-Verbose "List of services to check:";
	$AppServices | Format-Table;
}
$AppServices | Foreach-Object {
	$deployedResource = [DeployedResource]::new();
	$appService = $_;
	$appServiceName = $appService.ResourceName;
	$deployedResource.ServerName = $appServiceName;
	$deployedResource.ServiceName = $_.RolePurpose;
	$deployedResource.Error = '';
	$matchingResources = Get-MatchingStatus $deployedResource $StageName $appServiceName;
	if ($matchingResources.Count -gt 1)
	{
		$deployedResource = $matchingResources[1];
	}
	else
	{
		$deployedResource = $matchingResources;
	}
	$url = $urlFormat -f $appServiceName;
	try
	{
		$result = Invoke-WebRequest -Uri $url -ContentType "application/json";
		$content = $result.Content;
		Write-Verbose "Content: $($content)";
		$matches = [regEx]::Match($content,"^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$");
		$version = $matches.Groups[1].Value;
		if ([string]::IsNullOrWhiteSpace($version))
		{
			$length = [math]::Min(20,$result.Content.Length);
			Write-Host "$($appServiceName): , Role='$($appService.RolePurpose)' had unexpected result '$($result.Content.Substring(0,$length))...'" -ForegroundColor Yellow;
			$deployedResource.Error = $result.Content;
		}
		else
		{
			Write-Host "$($appServiceName): Version=$($version), Role='$($appService.RolePurpose)'" -ForegroundColor Cyan;
			$deployedResource.Version = $version;
		}
	}
	catch
	{
		$message = $error[0].Exception.Message;
		$deployedResource.Error = $message;
		$length = [math]::Min(80,$message.Length);
		Write-Host "$($appServiceName): '$($message.Substring(0,$length))...'" -ForegroundColor Red;
	}
	$newIndex = $deployedResources.Add($deployedResource);
	Write-Verbose $newIndex;
};
$currentContext = Set-AzContext -Context $currentContext;
ExportTo-Excel;
