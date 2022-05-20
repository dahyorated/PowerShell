<#
.SYNOPSIS
This script initiates the start-of-day connections and settings for EY usage of Azure.
.PARAMETER ConnectSubscription
This is the name of the Azure subscription used for the Azure CLI and Azure PowerShell connections.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False,ValueFromPipeline)]
	[string]$ConnectSubscription = "EY-CTSBP-NON-PROD-TAX-GTP CORE-01-39721502"
)

Write-Host "Connect for AZ CLI using '$($ConnectSubscription)' subscription.";
az login --use-device-code -o table;
az account set -s "$ConnectSubscription";
az configure -d organization="https://eyglobaltaxplatform.visualstudio.com/" project="Global Tax Platform";
Write-Host "Connect for PowerShell using Non-PRD Core Context in '$($ConnectSubscription)' subscription.";
Connect-AzAccount -Subscription "$ConnectSubscription" -UseDeviceAuthentication;
Get-AzSubscription | Format-Table -AutoSize;
Write-Host "Starting Visual Studio";
vs;
Write-Host "Daily devops updates";
cd \EYDev\devops\pipelines;
Get-ReleaseStatus;
Pull-AllLocalRepositories;
Export-AllDefinitions -UpdateGit;
