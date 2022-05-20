<#
.SYNOPSIS
Script to delete resource groups from subscriptions 

.DESCRIPTION
Script imports a csv file that contains information with list of resource groups that need to be deleted.
	$PSScriptRoot\..\provisioning\Resource-Groups\Remove-ResourceGroupsList.csv
	Each row of CSV file has information about the resource group that needs to be deleted. This information is required for the payload in call to the tower
	
Template-RemoveRSGPayload.json (stored in the same folder as the script)
	File is used to define a template for the payload.
	Get-Content "$PSScriptRoot\Template-RemoveRSGPayload.json"

Post call is made using the values imported from csv file and formatted to json according to the requirements set in Payload template file.

$SubscriptionList = Import-Csv  "File Path to csv file containing subscription info and variables"
It will be stored in deveops repo in provisioning\Templates folder and called Remove-ResourceGroupsList.csv

 Output Json file will be saved to \EYDev\devops\provisioning\Resource-Groups\ and will contain payload for every post call and job id

 spnId and spnsecret are retreived from appropriate keyvault using the StageName provided in the csv file

.Example
Remove-ResourceGroups.ps1


#>

[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param (
)

Function Remove-ResourceGroup
{
	param(
		[PSCustomObject]$Item
	)
	$payload =  $payloadContent | ConvertFrom-Json;	
	
	$rsg = Get-AzResourceGroup -name $Item.RSG -ErrorAction SilentlyContinue;
	if ($null -eq $rsg)
	{
		$errorMessage = "Get Resource group '{0}' does not exist" -f $Item.RSG;
		Write-Output $errorMessage;
		return;
	}
	#This is for main resource group
	$payload.extra_vars.AZURE_RM_CLIENTID = $spnId;
	$payload.extra_vars.AZURE_RM_SECRET = $spnSecret;
	$payload.extra_vars.var_azureRmSubId = $SubId;
	$payload.extra_vars.var_azure_rm_subid = $SubId;
	$payload.extra_vars.subscription_id = $SubId;
    $payload.extra_vars.var_resourceGroupName = $Item.RSG;
	$payload.extra_vars.var_tenantResourceGroupName = $Item.RSG;
	$payload.extra_vars.var_deploy_to = $Item.var_deploy_to;
	$payload.extra_vars.var_environment = $Item.environment;
	$payload.extra_vars.var_location = $Item.location;
	
	$jobId = Start-AnsibleJob $SubscriptionName $payload;
	$results = @{
		resourceGroupJob = $jobId
	};
	Write-Output ("Ansible job {0} is running." -f $jobid);
	$payload | Add-Member -MemberType NoteProperty -Name results -Value $results;
	Save-ProvisioningPayload $payload $Item.RSG $SubscriptionName;
	Show-AsJson $payload;
	if ($jobid -ne 0)
	{
		$jobStatus = Wait-JobCompletion $jobId;
		Write-Output ("$SubscriptionName {0}" -f $jobStatus);
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
    param(
		[string]$SubscriptionName,
		$CustomObject
	)
    $Jsonbody = $CustomObject | ConvertTo-Json -Depth 100 -Compress;
    $BaseURL = "https://gtpprovisioning.sbp.eyclienthub.com/api/tower?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg=="
	Try
    {
		$message = "Resource Group '{0}' in subscription '{1}'" -f $CustomObject.extra_vars.var_resourceGroupName,$SubscriptionName;
		if ($PSCmdlet.ShouldProcess($message,"Deleting"))
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
    $filename = "{0}\..\provisioning\Resource-Groups\Deleted-{1}-{2}.json" -f $PSScriptRoot,$resourceGroup,$SubscriptionName;
	$payload.extra_vars.AZURE_RM_SECRET = "***";
    $payload | ConvertTo-Json -Depth 100 | Out-File -Filepath $filename -Force -WhatIf:$false;
	$payload.extra_vars.AZURE_RM_SECRET = $spnSecret;
}

#Mainprocedure
Import-Module -Name $PSScriptRoot\DevOps -Force
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
#reading the default jsonfile to load parameters
$payloadContent = Get-Content "$PSScriptRoot\Template-RemoveRSGPayload.json";
$SubscriptionList = Import-Csv "$PSScriptRoot\..\provisioning\Resource-Groups\Remove-ResourceGroupsList.csv";
$ErrorsCount = 0;

foreach ($Item in $SubscriptionList)
{
	$SubscriptionName = $Item.SubscriptionName;
    Write-Output ("Subscription Name: {0}" -f $SubscriptionName);
    $SubId = ""
	$TenantId = ""
	try
	{
		$Subscription = Set-AzContext -SubscriptionName $Item.SubscriptionName -Confirm:$false -WhatIf:$false;
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
	Remove-ResourceGroup -Item $Item;

}
Write-Output "Total Errors '$ErrorsCount'";
