<#
.SYNOPSIS
Script to add default resource groups to subscriptions 

.DESCRIPTION
Imports a csv file that contains information with list of subscriptions and the needed information to create resource groups.
Each row of CSV file has information about different subscription.
Template-RSGPayload.json (stored in the same folder as the script)
File is used to define a template for the payload.
Get-Content "$PSScriptRoot\Template-RSGPayload.json"

Post call is made using the values imported from csv file and formatted to json according to the requirements set in Payload template file.

$SubscriptionList = Import-Csv "File Path to csv file containing subscription info and variables"
It will be stored in deveops repo in provisioning\Resource-Groups folder and called New-ResourceGroupsList.csv

The following values are always constant:
 $payload.extra_vars.var_skipEndpointConfig = "False" 
 $payload.extra_vars.var_deploy_to = "TENANT"

 Output Json file will be saved to \EYDev\devops\provisioning\Resource-Groups\ and will contain payload for every post call and job id

 spnId and spnsecret are retreived from appropriate keyvault using the StageName provided in the csv file

.Example
New-ResourceGroups.ps1


#>

[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param (
)

Function New-ResourceGroup
{
	param(
		[PSCustomObject]$Item,
		[bool]$isDr
	)
	$payload =  $payloadContent | ConvertFrom-Json;
	if ($isDr)
	{
		$rsg = Get-AzResourceGroup -name $Item.RSGDR -ErrorAction Ignore;
	}
	else
	{
		$rsg = Get-AzResourceGroup -name $Item.RSG -ErrorAction Ignore;
	}
	if ($null -eq $rsg)
	{
		#This is for main resource group
		$payload.extra_vars.AZURE_RM_CLIENTID = $spnId;
		$payload.extra_vars.AZURE_RM_SECRET = $spnSecret;
		$payload.extra_vars.var_azureRmSubId = $SubId;
		$payload.extra_vars.var_azure_rm_subid = $SubId;
		$payload.extra_vars.subscription_id = $SubId;
		$payload.extra_vars.var_skipEndpointConfig = "False";
		$payload.extra_vars.var_deploy_to = "TENANT";
		$payload.extra_vars.var_environment = $Item.environment;
		$payload.extra_vars.var_deploymentId = $Item.var_deploymentId;
		if ($isDr)
		{
			$payload.extra_vars.var_resourceGroupName = $Item.RSGDR;
			$payload.extra_vars.var_tenantResourceGroupName = $Item.RSGDR;
			$payload.extra_vars.var_location = $Item.locationDR;
		}
		else
		{
			$payload.extra_vars.var_resourceGroupName = $Item.RSG;
			$payload.extra_vars.var_tenantResourceGroupName = $Item.RSG;
			$payload.extra_vars.var_location = $Item.location;
		}
		$jobId = Start-AnsibleJob $payload;
		$results = @{
			resourceGroupJob = $jobId
		};
		Write-Output ("Ansible job {0} is running." -f $jobid);
		$payload | Add-Member -MemberType NoteProperty -Name results -Value $results;
		if ($isDr)
		{
			Save-ProvisioningPayload $payload $Item.RSGDR $SubscriptionName;
		}
		else
		{
			Save-ProvisioningPayload $payload $Item.RSG $SubscriptionName;
		}
		Show-AsJson $payload;
		if ($jobid -ne 0)
		{
			$jobStatus = Wait-JobCompletion $jobId;
			Write-Output ("$SubscriptionName {0}" -f $jobStatus);
		}
	}
}

function Show-AsJson {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$CustomObject
    )
	$CustomObject.extra_vars.AZURE_RM_SECRET = "***";
    Write-Output ($CustomObject | ConvertTo-Json)
    Write-Output "================="
	$CustomObject.extra_vars.AZURE_RM_SECRET = $spnSecret;
    }

function Start-AnsibleJob {
    param( $CustomObject )
    $Jsonbody = $CustomObject | ConvertTo-Json -Depth 100 -Compress;
    $BaseURL = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
	Try
    {
		$message = "Creating Resource Group '{0}'" -f $CustomObject.extra_vars.var_resourceGroupName;
		if ($PSCmdlet.ShouldProcess($message))
		{
			try
			{
				$Response = Invoke-RestMethod -Uri $BaseURL -Method Post -ContentType "application/json" -Body $Jsonbody; 
				return $Response.msg.jobid;
			}
			catch
			{
				Show-AsJson -CustomObject $CustomObject;
				$errorMessage = "{0} failed: {1}" -f $message,$_.Exception.Message;
				Stop-ProcessError -errorMessage $errorMessage;
			}
		}
		else
		{
			return "0";
		}
    }
	Catch 
	{
		Write-Output "exception";
		write-output $_;
		Exit;
	}
}

Function Save-ProvisioningPayload
{
    param(
        [PSCustomObject]$payload,
        [string]$resourceGroup,
		[string]$SubscriptionName
    )
    $filename = "{0}\..\provisioning\Resource-Groups\Created-{1}-{2}.json" -f $PSScriptRoot,$resourceGroup,$SubscriptionName;
	$payload.extra_vars.AZURE_RM_SECRET = "***";
    $payload | ConvertTo-Json -Depth 100 | Out-File -Filepath $filename -Force -WhatIf:$false;
	$payload.extra_vars.AZURE_RM_SECRET = $spnSecret;
}

#Mainprocedure
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
#reading the default jsonfile to load parameters
$payloadContent = Get-Content "$PSScriptRoot\Template-RSGPayload.json";
$SubscriptionList = Import-Csv "$PSScriptRoot\..\provisioning\Resource-Groups\New-ResourceGroupsList.csv";
$ErrorsCount = 0;

foreach ($Item in $SubscriptionList)
{
    $SubscriptionName = $Item.SubscriptionName;
    Write-Output ("Subscription Name: {0}" -f $SubscriptionName);
    $SubId = ""
	$TenantId = ""
	try
	{
		$Subscription = Set-AzContext -SubscriptionName $Item.SubscriptionName -ErrorAction Stop;
		if ($isVerbose) { $Subscription;}
	}
	catch
	{
		Write-Output "$($item.Subscription) Not found";
		$ErrorsCount++;
		continue;
	}
	$Subscription = Get-AzSubscription -SubscriptionName $Item.SubscriptionName;
	$SubId = $Subscription.Id;
	Write-Output ("Subscription ID: {0}" -f $SubId);
	$TenantId = $Subscription.TenantId;
	Write-Output ("Tenant ID: {0}" -f $TenantId);
	$spn = Get-SpnInfoFromStageName -StageName $Item.StageName;
	$spnId = $spn.SpnId;
	$spnSecret = $spn.SpnPassword;
	New-ResourceGroup -Item $Item -isDr $false;
	New-ResourceGroup -Item $Item -isDr $true;
}
Write-Output "Total Errors '$ErrorsCount'";
