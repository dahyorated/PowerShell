<#
.Synopsis
Deploy Boardwalk for all Clients

.Description
The Deploy-BoardWalkForEnvironment script deploys Boardwalk for all Clients in the provided environment.

This script is intended to be used within a release pipeline.

.Parameter CoreVaultName
This is the core key vault name for the environment.
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory=$true)]  [string]$CoreVaultName,
	[Parameter(Mandatory=$true)]  [string]$AzureLoginURL,
	[Parameter(Mandatory=$true)]  [string]$AzureTaxFactDataServiceBaseURLName,
	[Parameter(Mandatory=$true)]  [string]$WarFile,
	[Parameter(Mandatory=$true)]  [string]$AzureGTPvalidateEP,
	[Parameter(Mandatory=$true)]  [string]$AzureServiceTokenURLName,
	# used for interacting with client routing
	[Parameter(Mandatory=$true)]  [string]$AuthService,
	[Parameter(Mandatory=$true)]  [string]$ClientService,
	[Parameter(Mandatory=$true)]  [string]$ServiceID,
	[Parameter(Mandatory=$true)]  [string]$ServiceAuthSecret,
	# used for interacting with Azure Resources
	[Parameter(Mandatory=$true)]  [string]$SubscriptionIdCore,
	[Parameter(Mandatory=$true)]  [string]$ResourceGroupNameCore,
	[Parameter(Mandatory=$true)]  [string]$BuildNumber,
	[Parameter(Mandatory=$true)]  [Boolean]$IsPrimarySite,
	[Parameter(Mandatory=$true)]  [string]$BwServiceName = "boardwalk",
	# app service configuration values
	[Parameter(Mandatory=$false)]  [string]$JavaVersion = "1.8.0_181_ZULU",
	[Parameter(Mandatory=$false)]  [string]$JavaContainer = "TOMCAT",
	[Parameter(Mandatory=$false)]  [string]$JavaContainerVersion = "9.0.12",
	[Parameter(Mandatory=$false)]  [string]$AlwaysOn = "true",
	[Parameter(Mandatory=$false)]  [string]$Use32BitWorkerProcess = "false",
	# the app service folder that needs deletion and inbound WAR file
	[Parameter(Mandatory=$false)]  [string]$FolderToDelete = 'webapps/ROOT/',
	# get set as appSettings on the App Service
	[Parameter(Mandatory=$false)]  [string]$BoardwalksmtpAddress = 'boardwalk.no.reply@ey.com',
	[Parameter(Mandatory=$false)]  [string]$BoardwalksmtpPassword = '',
	[Parameter(Mandatory=$false)]  [string]$Boardwalksmtpport = '1025',
	[Parameter(Mandatory=$false)]  [string]$Boardwalksmtpserver = 'gtpwebmail.westeurope.cloudapp.azure.com',
	[Parameter(Mandatory=$false)]  [string]$BoardwalksmtpuserName = '',
	[Parameter(Mandatory=$false)]  [string]$WebsiteHttpLoggingRetentionDays =  '15',
	[Parameter(Mandatory=$false)]  [string]$AzureDBlogFlag =  '1',
	[Parameter(Mandatory=$false)]  [string]$SpecificClientId =  "",
	[Parameter(Mandatory=$false)]  [string]$azureNotifyEYAPI = "" #url for the apac cit client cfg service in a given environment
)

function deployAppSettings( $AppServiceName, $PublicUrl, $ResourceGroupNameTenant, $AppServicePlanName )
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			# app settings ... lots of parameters here:
			$appSettingsObject = @{
				azureBaseURLName = $PublicUrl;
				azureGTPvalidateEP = $AzureGTPvalidateEP;
				azureServiceTokenURLName = $AzureServiceTokenURLName;
				azureTaxFactDataServiceBaseURLName = $AzureTaxFactDataServiceBaseURLName;
				boardwalksmtpAddress = $BoardwalksmtpAddress;
				boardwalksmtpPassword = $BoardwalksmtpPassword;
				boardwalksmtpport = $Boardwalksmtpport;
				boardwalksmtpserver = $Boardwalksmtpserver;
				boardwalksmtpuserName = $BoardwalksmtpuserName;
				WEBSITE_HTTPLOGGING_RETENTION_DAYS = $WebsiteHttpLoggingRetentionDays;
				azureDBlogFlag = $AzureDBlogFlag;
				azureLoginURL = $AzureLoginURL;
				BuildNumber = $BuildNumber
			};
			#this is an optional app setting required for BW only
			if (-not [string]::IsNullOrWhiteSpace($azureNotifyEYAPI))
			{
				$appSettingsObject.azureNotifyEYAPI = $azureNotifyEYAPI;
			}
			Set-AzWebApp -ResourceGroupName $ResourceGroupNameTenant `
				-AppServicePlan $AppServicePlanName `
				-Name $AppServiceName `
				-ErrorAction Stop `
				-AppSettings $appSettingsObject;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "... error occurred while in deployAppSettings ...";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function getCurrentDeployedBoardwalkVersion($AppServiceName, $ResourceGroupNameTenant, $AppServicePlanName)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			$appservice = Get-AzWebApp -Name $AppServiceName -ResourceGroupName $ResourceGroupNameTenant;
			$appSettings = $appservice.SiteConfig.AppSettings;
			foreach ($item in $appSettings)
			{
				if ($item.Name -eq "BuildNumber"){
					$buildNumber = $item.Value;
					return $buildNumber;
				}
			}
			return "0.0.0.0"; # default value in the event that this service doesn't have the appSetting for the build number
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "... error occurred while in getCurrentDeployedBoardwalkVersion ..."
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function getOriginalTagsFromWebApp($appServiceName)
{	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			$originalTags = (Get-AzWebApp -Name $appServiceName).Tags;
			return $originalTags;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in getOriginalTagsFromWebApp for AppService: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return 'FAILURE';
}

function deployTags ($AppServiceName, $ClientId, $ServiceName, $ResourceGroupNameTenant, $OriginalTags)
{
	$ErrorActionPreference = "Stop";
	#there are cases when the tags get wiped out as part of the release; luckily now
	# we saved them at the beginning ... just need to re-apply them
	$retryCount = 0;
	do
	{
		try
		{
			$resource = Get-AzResource -ResourceName $AppServiceName -ResourceGroupName $ResourceGroupNameTenant -ResourceType "Microsoft.Web/sites";
			Set-AzResource -Tag $OriginalTags -ResourceId $resource.ResourceId -Force;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in deployTags for AppService: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function deployConfiguration($AppServiceName, $ClientId, $ResourceGroupNameTenant)
{
	$ErrorActionPreference = "Stop";
	do
	{
		try
		{
		$configObject = @{javaVersion=$JavaVersion;
				javaContainer=$JavaContainer;
				javaContainerVersion=$JavaContainerVersion;
				alwaysOn=$AlwaysOn;
				use32BitWorkerProcess=$Use32BitWorkerProcess};
			Set-AzResource -PropertyObject $configObject `
				-ResourceGroupName $ResourceGroupNameTenant `
				-ResourceType 'Microsoft.Web/sites/config' `
				-ResourceName "$AppServiceName/web" `
				-ErrorAction Stop `
				-ApiVersion '2015-08-01' -Force ;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in deployConfiguration for AppService: $AppServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function deployConnectionString ($AppServiceName, $bwDbPw, $bwDbName, $bwDbUserName, $bwDbServer, $ResourceGroupNameTenant, $AppServicePlanName)
{
	$ErrorActionPreference = "Stop";
	do
	{
		try
		{
			# CONNECTION STRING:
			$connString = 'jdbc:sqlserver://{0}:1433;database={1};user={2}@{0};password={3};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;' -f $bwDbServer,$bwDbName,$bwDbUserName,$bwDbPw;
			$connObject = @{
							boardwalkclient=@{
									Type="SQLAzure";
									Value=$connString
							}
						};
			Set-AzWebApp -ResourceGroupName $ResourceGroupNameTenant `
							-AppServicePlan $AppServicePlanName `
							-Name $AppServiceName.ToLower() `
							-ErrorAction Stop `
							-ConnectionStrings $connObject ;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in deployConnectionString for AppService: $AppServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function setAzContext($azureSubscriptionId)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			Set-AzContext -SubscriptionId $azureSubscriptionId;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in setAzContext for AppService...";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function getAppServicePlanName($serverFarmResourceString)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			# this is a magic line
			$AppServicePlanName = (Get-AzResource -ResourceId $serverFarmResourceString).Name;
			return $AppServicePlanName;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in getAppServicePlanName...";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return "FAILURE";
}

function stopAppService($appServiceName, $ResourceGroupNameTenant)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			Stop-AzWebApp  -ResourceGroupName $ResourceGroupNameTenant -Name $appServiceName;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in stopAppService for AppService: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function startAppService($appServiceName, $ResourceGroupNameTenant)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			Start-AzWebApp  -ResourceGroupName $ResourceGroupNameTenant -Name $appServiceName;
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in startAppService for AppService: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function getKuduApiAuthorizationToken($appServiceName, $ResourceGroupNameTenant, $kuduCredsObject)
{
	try
	{
		if ($null -eq  $kuduCredsObject)
		{
			# get kudu login credentials
			$resourceType = "Microsoft.Web/sites/config";
			$resourceName = "$appServiceName/publishingcredentials" ;
			$invokeResourceActionSuccess = invokeResourceAction -ResourceGroupNameTenant $ResourceGroupNameTenant -resourceType $resourceType -resourceName $resourceName;
			if ($invokeResourceActionSuccess -eq "FAILURE")
			{
				Write-Host "Failed to get Kudu Creds for App Service $appServiceName; Exit Release Script.";
				return 'FAILURE';
			}
			$publishingCredentials = $invokeResourceActionSuccess;
			$kuduCredsObject = @{};
			$un = $publishingCredentials.Properties.PublishingUserName;
			$pw = $publishingCredentials.Properties.PublishingPassword;
			$kuduCredsObject.un = $un;
			$kuduCredsObject.pw = $pw;
			$creds =  ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $un,$pw))));
			$kuduCredsObject.token = $creds;
		}
		return $kuduCredsObject;
	}
	catch
	{
		$exName = $_.Exception.GetType().FullName;
		Write-Host "... error occurred in getKuduApiAuthorizationToken ..."
		Write-Host "... details Name: $exName ...";
		Write-Host "... details Message: $($_.Exception.Message) ...";
		return 'FAILURE';
	}
}

function getKuduApiUrl($appServiceName, $filePath)
{
	$kuduApiUrl = "https://$appServiceName.scm.azurewebsites.net/api/vfs/site/wwwroot/$filePath";
	return $kuduApiUrl;
}

function getKudiCommandApiUrl ($appServiceName )
{
	$kuduApiUrl = "https://$appServiceName.scm.azurewebsites.net/api/command";
	return $kuduApiUrl;
}

function deleteAppServiceFiles($appServiceName, $ResourceGroupNameTenant, $kuduCredsObject)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			$body = @"
			{
				"command":"rmdir site\\wwwroot\\webapps /s/q",
				"dir":""
			}
"@;
			$headers = @{"Authorization"=$kuduCredsObject.token;"If-Match"="*"};
			$kudiApiURL = getKudiCommandApiUrl -appServiceName $appServiceName ;
			$result = Invoke-RestMethod -Uri $kudiApiURL -Headers $headers -Method Post -Body $body -ContentType "application/json";
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in deleteAppServiceFiles for App Service.";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			if ($_.Exception.Message -like '*404*')
			{
				# this can sometimes be expected, especially in the case of re-running a release that crashed mid-deploy on a newly provisioned BW app service
				return $true; # return that we are OK in this case
			}
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function getFileListFromWebApp($appServiceName, $filePath, $ResourceGroupNameTenant, $kuduCredsObject)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			# need a list of all the directories in the folder where we are targetting deletion
			# $kuduApiAuthorisationToken = getKuduApiAuthorizationToken -appServiceName $appServiceName -ResourceGroupNameTenant $ResourceGroupNameTenant;
			$kuduApiUrl =  getKuduApiUrl -appServiceName $appServiceName -filePath $filePath;   # "https://$appServiceName.scm.azurewebsites.net/api/vfs/site/wwwroot/$filePath"
			$fileList = Invoke-RestMethod -Uri $kuduApiUrl -Method GET -ContentType "multipart/form-data" -Headers @{"Authorization"=$kuduCredsObject.token;"If-Match"="*"};
			return $fileList;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in getFileListFromWebApp for App Service: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			if ($_.Exception.Message -like '*404*')
			{
				# this can sometimes be expected, especially in the case of re-running a release that crashed mid-deploy on a newly provisioned BW app service
				return @(); # return an empty array
			}
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return "FAILURE";
}

function invokeResourceAction($ResourceGroupNameTenant, $resourceType, $resourceName)
{
	do
	{
		try
		{
		$publishingCredentials = Invoke-AzResourceAction -ResourceGroupName $ResourceGroupNameTenant -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2015-08-01 -Force ;
			return $publishingCredentials;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred while getting credentials in invokeResourceAction for ResourceName: $resourceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return "FAILURE";
}

function getWebApp($appServiceName)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			$appService = Get-AzWebApp -Name $appServiceName;
			return $appService;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in getWebApp for AppService: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return "FAILURE";
}

function deployWarFile($appServiceName, $ResourceGroupNameTenant, $kuduCredsObject)
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			Write-Host "... attempting sending WAR file to: $appServiceName";
			$httpUserAgent =  ${env:AZURE_HTTP_USER_AGENT};
			$msDeployPath = '"C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"';
			$arguments = " -verb:sync -source:contentPath='{0}' -dest:contentPath='/site/webapps/ROOT.war',ComputerName='https://{1}.scm.azurewebsites.net:443/msdeploy.axd?site={1}',UserName='{2}',Password='{3}',AuthType='Basic' -enableRule:DoNotDeleteRule -userAgent:{4}"  -f $WarFile, $appServiceName, $kuduCredsObject.un, $kuduCredsObject.pw, $httpUserAgent;
			Write-Host "... now have all the strings we need to execute msdeploy to push WAR File";
			Write-Host "... executing WAR deployment ...";
			Write-Host  "$msDeployPath $arguments" ;
			Start-Process -FilePath $msDeployPath -args $arguments -NoNewWindow -Wait;
			Write-Host "... completed WAR deployment ...";
			return $true;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "...Error occurred in deployWarFile for AppService: $appServiceName";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return $false;
}

function authenticateAndGetClientConfigs()
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
			Write-Host "Getting Client Configurations for ServiceID $ServiceID AuthService $AuthService ClientService $ClientService";
			# Get service auth token
			$serviceLogin = @{
				serviceId = $ServiceID
				secret    = $ServiceAuthSecret
			}
			# Specify we only need a short-lived token
			$headers = @{
				"X-Token-Expiration-Minutes" = "15"
				"Accept"                     = "application/json"
				"Content-Type"               = "application/json"
			}
			Write-Host  "Getting token from AuthService";
			$response = Invoke-RestMethod -Method Post -Uri "$AuthService/api/v1/authenticate/service" -Body (ConvertTo-Json $serviceLogin) -Headers $headers -ContentType "application/json"
			$token = $response.token
			$Script:serviceBearerToken = $token;
			# Get configuration data for all clients
			$authHeaders = @{
				Authorization = "Bearer $token"
				"Accept"      = "application/json"
			}
			Write-Host "Getting client configurations from client service";
			$clientConfigUri = "";
			if ("" -ne $SpecificClientId )
			{
				$clientConfigUri = "$ClientService/api/client/$SpecificClientId/configuration?onlyProvisioned=false"
				Write-Host "... Getting ClientConfig for SpecificClientId: $SpecificClientId";
			}
			else
			{
				$clientConfigUri = "$ClientService/api/client/configuration"
				Write-Host "... Getting ClientConfig for all Client IDs";
			}
			Write-Host $clientConfigUri;
			$ErrorActionPreference = "Stop";
			# create a loop that cycles a number of make sure the client routing service is not down
			$clientConfigs = Invoke-RestMethod -Method Get -Uri $clientConfigUri -Headers $authHeaders ;
			# no exceptions hitting the client routing API; return the resultset
			return $clientConfigs;
		}
		catch
		{
			# error encountered; will retry based on the error type based on common 5## errors we see with the client service isn't ready.
			if (($_.Exception.Message -like '*500*')  `
					-or ($_.Exception.Message -like '*502*') `
					-or ($_.Exception.Message -like '*503*') `
					-or ($_.Exception.Message -like '*504*'))
			{
				Write-Host "Error occurred during call to client routing service $($_.Exception.Message) ";
				Write-Host "Sleeping for 5 seconds. ";
				Start-Sleep -Seconds 5;
				Write-Host "Done sleeping; going to try again.";
			}
			#we didn't catch an expected HTTP Error code; let's just log it and fix it
			Write-Host "Unexpected error occurred while using client routing service: $($_.Exception.Message) ";
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return "FAILURE";
}

function getClientSubscriptionConfigs()
{
	$ErrorActionPreference = "Stop";
	$retryCount = 0;
	do
	{
		try
		{
			# get connection string to client DB either from KeyVault or from client routing service
			# create collection of Subscription / Client cross reference objects
			$authHeaders = @{
				Authorization = "Bearer $Script:serviceBearerToken"
				"Accept"      = "application/json"
			};
			$platformConfigUrl =  "$ClientService/api/configuration";
			$platformConfigs = Invoke-RestMethod -Method Get -Uri $platformConfigUrl -Headers $authHeaders;
			$clientDbConfigObject = $platformConfigs.platformDatabases |  Where-Object {$_.service -eq "clientservice" };
			if ($null -eq $clientDbConfigObject)
			{
				Write-Host "Could not find the clientDbConfigObject from the platformDatabases configuration.";
			}
			$clientSubscription_SQL = "
				select ccl.ClientId
					, ccl.Clientnm
					, csub.SubscriptionName
					, csub.AzureSubscriptionID
					, csub.TenantId
					, csub.SPNName
					, csub.SPNId
					, csub.OmsWorkSpaceId
					, csub.PrimaryAppServicePlan
					, csub.OmsWorkSpaceResourceGroup
					, csub.SecondaryAppServicePlan
					, csub.OmsWorkSpaceName
					, csub.TenantPrimaryResourceGroupName
					, csub.TenantSecondaryResourceGroupName
				from common.Client ccl
				inner join common.ClientSubscription ccs on ccl.ClientId = ccs.ClientId
				inner join common.Subscription csub on ccs.SubscriptionID = csub.SubscriptionId
";
			$clientSubDataTable = Invoke-Sqlcmd -OutputAs DataTables -Password $clientDbConfigObject.password -Username $clientDbConfigObject.username -Database $clientDbConfigObject.database -ServerInstance $clientDbConfigObject.server -Query $clientSubscription_SQL;
			if (0 -eq $clientSubDataTable.Rows.Count)
			{
				Write-Host "No rows/records returned from clientSubscription_SQL query.";
			}
			$clientSubObjects = @();
			foreach ($Row in $clientSubDataTable)
			{
				$Properties = @{}
				For($i = 0;$i -le $Row.ItemArray.Count - 1;$i++)
				{
					$Properties.Add($clientSubDataTable.Columns[$i], $Row.ItemArray[$i])
				}
				$clientSubObjects += New-Object -TypeName PSObject -Property $Properties
			}
			return $clientSubObjects;
		}
		catch
		{
			$exName = $_.Exception.GetType().FullName;
			Write-Host "Error occurred in getClientSubscriptionConfigs.";
			Write-Host "... details ... $exName";
			Write-Host "... details ... $($_.Exception.Message) ";
			Start-Sleep -Seconds 5;
		}
		$retryCount++;
	} while ($retryCount -le $Script:maxRetryCount)
	return "FAILURE";
}


# Execution of script begins here
Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output ("Starting {0}." -f [System.IO.Path]::GetFileNameWithoutExtension($PSCmdlet.MyInvocation.InvocationName));
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials;
# DevOps note, command to make the WAR file in either the WarFile or ApacWarFile directory
# jar -cvf ROOT.war *

# script assumes being executed in the pipelines in the context of an SPN that has Tenant subscription access
# To debug the script, provide the -Debug switch parameter.
# Change the subscription ID to emulate the tenant or core sub id that you want to test/debug locally.  For example,
if ($Debug)
{
	#Set-AzContext -SubscriptionId '0e24abb5-5296-4edf-a4ba-d95f6fdc39d1'; #Dev Tenant
	Set-AzContext -SubscriptionId '5aeb8557-cab7-41ac-8603-9f94ad233efc'; #Dev Core
	#Set-AzContext -SubscriptionId 'e45bb7e2-b46d-4f73-b12f-66c7ed1c97b7'; #Stage Core
}
# this is the context in which the Azure PowerShell task is running as
$defaultContextId = (Get-AzContext).Subscription.Id;
$maxRetryCount = 12;
$serviceBearerToken = "";
$clientConfigs = authenticateAndGetClientConfigs;
$clientSubscriptionConfigs = getClientSubscriptionConfigs;
if ($clientSubscriptionConfigs -eq "FAILURE")
{
	$errorMessage = "Failed to get client/subscription mappings from the clientSubscription_SQL query.";
	Stop-ProcessError -ErrorMessage $errorMessage;
}
Write-Output "we now have necessary configuration and subscription collections";
$startTime = Get-Date;
$clientCount = $clientConfigs.Count;
$currentClient = 0;
# this is the loop that does the work
foreach ($clientConfig in $clientConfigs)
{
	$currentClient++;
	Write-Debug "Processing '$($clientConfig.clientId)'.";
	if ($null -eq $clientConfig.clientId)
	{
		$tenantId = "--NULL";
	}
	else
	{
		$tenantId = $clientConfig.clientId.ToString().PadLeft(6,"0");
	}
	Write-Output ("==> Processing client '{0}' ({1} of {2})." -f $tenantId,$currentClient,$clientCount);
	# here we grab the client ID ... but most everything else will be in the child "clientserviceconfiguration" collection
	$clientid = $clientConfig.clientId.ToString();
	$bwDbPassword = '';
	$bwDbName = '';
	$bwDbUserName = '';
	$bwDbServer = '';
	Write-Output "processing thru client list returned by ClientService call, examining clientId: $clientid";
	if ("" -ne $SpecificClientId -and $clientid -ne $SpecificClientId)
	{
		Write-Output "Current Client ID does not match the requested Specific ClientId; continuing.";
		# In the event that SpecificClientId is specified we check to see if we are on that clientid; if not we skip/continue.
		# This is to be able to process an integration with client provisioning so they can send
		#   the BW App Service to a newly provisioned app service and JUST that one app service without
		#   having to reprovision every client and possible causing a service interruption
		continue;
	}
	$boardwalkServiceConfigs = $clientConfig.clientServiceConfigurations | Where-Object {$_.service -eq $BwServiceName };
	if ($null  -eq $boardwalkServiceConfigs)
	{
		Write-Output "did not find any boardWalkServiceConfigs from the Client Service Configuration API"
	}
	foreach ( $bwServConfig in $boardwalkServiceConfigs )
	{
		if ([string]::IsNullOrWhiteSpace($bwServConfig.storageAccount))
		{
			# $bwServConfig.storageAccount, which stores the App Service Name, was blank/empty which means there was nothing we can do.
			continue;
		}
		$currentServiceType = $bwServConfig.service;
		foreach ($servDbLookup in $boardwalkServiceConfigs  )
		{
			if (($servDbLookup.resourceTypeId -eq 2) -and ($servDbLookup.service -eq $currentServiceType)) #2 is the database record
			{
				$bwDbPassword = $servDbLookup.password;
				$bwDbName = $servDbLookup.database;
				$bwDbUserName = $servDbLookup.username;
				$bwDbServer = $servDbLookup.server;
			}
		}
		$thisSubscriptionId = "";
		$ResourceGroupNameTenant = "";
		$AppServicePlanName = "";
		# look up necessary Azure subscription details from the $clientSubscriptionConfigs array and set context and set RG name variable
		# if the client we are on isn't in the $clientSubscriptionConfigs array, then we don't have enough information
		#		to process it.  we should output that we can't work on it and skip it
		$existsInAzure = $clientSubscriptionConfigs | Where-Object {$_.ClientId -eq  $clientid };
		if ($null -eq $existsInAzure)
		{
			$thisSubscriptionId = $Script:defaultContextId;
			Write-Output "Cannot find Azure Subscription Information for ClientID: $clientid in the subscription table. ";
			Write-Output "Will attempt to use the default context $thisSubscriptionId instead."
			# even if it doesn't exist in the subscription tables, it may still exist as a default client before the Sub tables were introduced
			# let's set our context back to the context of the pipeline which was also the SPN over the original tenant subscription
			$setAzContextSuccess = setAzContext -azureSubscriptionId $thisSubscriptionId;
			if (!($setAzContextSuccess))
			{
				$errorMessage = "Failed to set Az Context on $thisSubscriptionId; exiting release script.";
				Stop-ProcessError -ErrorMessage $errorMessage;
			}
			# now we need the to see if we can
			$getWebAppSuccess = getWebApp -appServiceName $bwServConfig.storageAccount;
			if ($getWebAppSuccess -eq "FAILURE")
			{
				$errorMessage = "Failed to set Get Web App on $($bwServConfig.storageAccount); exiting release script.";
				Stop-ProcessError -ErrorMessage $errorMessage;
			}
			$thisWebApp = $getWebAppSuccess;
			if ($null -eq $thisWebApp)
			{
				#we could not find this app service in the default/spn subscription ... we can only skip at this point:
				Write-Output "could not find $($bwServConfig.storageAccount) in any subscription."
				continue;
			}
			else
			{
				# if we got a web app while in this subscription that is a good sign; we can get our other variables from that
				$ResourceGroupNameTenant = $thisWebApp.ResourceGroup;
				$getAppServicePlanSuccess =  getAppServicePlanName -serverFarmResourceString $thisWebApp.ServerFarmId;
				if ($getAppServicePlanSuccess -eq "FAILURE")
				{
					$errorMessage = "Failed to get App Service Plan for $thisWebApp; exiting release script.";
					Stop-ProcessError -ErrorMessage $errorMessage;
				}
				# since we didn't fail, we must have gotten the plan name back
				$AppServicePlanName = $getAppServicePlanSuccess;
			}
		}
		else
		{
			$thisSubscriptionId = $existsInAzure[0].AzureSubscriptionID;
			if ($true -eq $IsPrimarySite)
			{
				$AppServicePlanName = $existsInAzure[0].PrimaryAppServicePlan;
				$ResourceGroupNameTenant = $existsInAzure[0].TenantPrimaryResourceGroupName;
			}
			else
			{
				$AppServicePlanName = $existsInAzure[0].SecondaryAppServicePlan;
				$ResourceGroupNameTenant = $existsInAzure[0].TenantSecondaryResourceGroupName;
			}
			Write-Output "Attempting to set Az-Context to: $thisSubscriptionId";
			$setAzContextSuccess =  setAzContext -azureSubscriptionId $thisSubscriptionId  ;
			if (!($setAzContextSuccess))
			{
				$errorMessage = "Failed to set Az Context on $thisSubscriptionId; exiting release script.";
				Stop-ProcessError -ErrorMessage $errorMessage;
			}
			Write-Output "Successfully set Az-Context to: $thisSubscriptionId";
		}
		$webapp = $bwServConfig.storageAccount ;
		Write-Output "... begin checking current deployed version on app service: $webapp ...";
		$checkAppVersionSuccess = getCurrentDeployedBoardwalkVersion -AppServiceName $webapp -ResourceGroupNameTenant $ResourceGroupNameTenant -AppServicePlanName $AppServicePlanName;
		if ($false -eq $checkAppVersionSuccess)
		{
			$errorMessage = "Failed to get current deployed BW Version from $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done checking current deployed version on app service: $webapp ...";
		if ($BuildNumber -eq $checkAppVersionSuccess)
		{
			Write-Output "Release Build Number matches App Service, $webapp, Build Number: $BuildNumber ... Continuing."
			continue;
		}
		Write-Output "Release Build Number, $BuildNumber, does not match version deployed on App Service, $webapp, with Build Number: $checkAppVersionSuccess.  Will deploy requested version to this App Service.";
		Write-Output "Starting Process: configuration and release BW War File for clientId: $clientid to App Service: $webapp";
		Write-Output "... begin getting original tags from appService..."
		$getOriginalTagsSuccess = getOriginalTagsFromWebApp -appServiceName $webapp;
		if ('FAILURE' -eq $getOriginalTagsSuccess)
		{
			$errorMessage = "Failed to get Tags from $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done begin getting original tags from appService..." -
		$publicUrl = "https://" + $bwServConfig.resourceURL;
		Write-Output "... web-account: $($bwServConfig.storageAccount) (in the storage account field)";
		Write-Output "... begin populate kudu credentials..."
		$kuduCredsObject = $null; # reset the Kudu creds
		$getKuduApiAuthorizationTokenSuccess = getKuduApiAuthorizationToken -appServiceName $webapp -ResourceGroupNameTenant $ResourceGroupNameTenant -KuduCredsObject $kuduCredsObject;
		if ('FAILURE' -eq $getKuduApiAuthorizationTokenSuccess)
		{
			$errorMessage = "Failed to Get Kudu Api Authorization Token to $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		$kuduCredsObject = $getKuduApiAuthorizationTokenSuccess;
		Write-Output "... done populate kudu credentials..."
		Write-Output "... begin configuration $webapp";
		$deployConfigurationSuccess = deployConfiguration -AppServiceName  $webapp -ClientId $clientid -ResourceGroupNameTenant $ResourceGroupNameTenant;
		if (!($deployConfigurationSuccess))
		{
			$errorMessage = "Failed to Deploy Configuration to $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done configuration $webapp";
		Write-Output "... begin stopping app service: $webapp";
		$stopAppServicesuccess = stopAppService -appServiceName  $webapp  -ResourceGroupNameTenant $ResourceGroupNameTenant;
		if (!($stopAppServicesuccess))
		{
			$errorMessage = "Failed to Stop App Service $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done stopping app service: $webapp";
		Write-Output "... begin file delete step ...";
		$deleteAppServiceFilesSuccess = deleteAppServiceFiles  -appServiceName $webapp -kuduCredsObject $kuduCredsObject -ResourceGroupNameTenant $ResourceGroupNameTenant;
		if(!($deleteAppServiceFilesSuccess))
		{
			$errorMessage = "Failed to Delete App Service File Content $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done file delete step ...";
		# Write-Output "... begin folder delete step ...";
		# $deleteAppServiceFolderContentSuccess = deleteAppServiceFolderContent -appServiceName $webapp -filePath $FolderToDelete -recursive $true -ResourceGroupNameTenant $ResourceGroupNameTenant -kuduCredsObject $kuduCredsObject;
		# if (!($deleteAppServiceFolderContentSuccess))
		#{	 $errorMessage = "Failed to Delete App Service Folder Content $webapp; exiting release script.";
		#	Stop-ProcessError -ErrorMessage $errorMessage;
		#}
		# Write-Output "... done folder delete step ...";
		Write-Output "... begin deploy app service: $webapp";
		$deployWarFileSuccess = deployWarFile -appServiceName $webapp -ResourceGroupNameTenant $ResourceGroupNameTenant -kuduCredsObject $kuduCredsObject;
		if (!($deployWarFileSuccess))
		{
			$errorMessage = "Failed to Deploy War File $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done deploying app service: $webapp";
		Write-Output "... begin app settings: $webapp";
		$deployAppSettingsSuccess = deployAppSettings -AppServiceName $webapp -PublicUrl $publicUrl -ResourceGroupNameTenant $ResourceGroupNameTenant -AppServicePlanName $AppServicePlanName;
		if (!($deployAppSettingsSuccess))
		{
			$errorMessage = "Failed to Deploy App Settings $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done app settings: $webapp";
		Write-Output "... begin set connection string: $webapp";
		$deployConnectionStringSuccess = deployConnectionString  -AppServiceName $webapp  -bwDbName $bwDbName -bwDbUserName $bwDbUserName -bwDbPw $bwDbPassword -bwDbServer $bwDbServer -ResourceGroupNameTenant $ResourceGroupNameTenant -AppServicePlanName $AppServicePlanName;
		if (!($deployConnectionStringSuccess))
		{
			$errorMessage = "Failed to Deploying Connection String to $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done set connection string: $webapp" ;
		Write-Output "... begin set resource tags: $webapp";
		$deployTagsSuccess = deployTags -AppServiceName $webapp -ClientId $clientid -ServiceName $bwServConfig.service -ResourceGroupNameTenant $ResourceGroupNameTenant -OriginalTags $getOriginalTagsSuccess;
		if (!($deployTagsSuccess))
		{
			$errorMessage = "Failed to Deploy Tags to $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done set resource tags: $webapp";
		Write-Output "... begin starting app service: $webapp";
		$startAppServiceSuccess = startAppService -appServiceName $webapp -ResourceGroupNameTenant $ResourceGroupNameTenant;
		if (!($startAppServiceSuccess))
		{
			$errorMessage = "Failed to Start App Service $webapp; exiting release script.";
			Stop-ProcessError -ErrorMessage $errorMessage;
		}
		Write-Output "... done restarting app service: $webapp";
	}
	$endTime = Get-Date;
	$elapsedHours = ($endTime-$startTime).TotalHours;
	$remainingClients = $clientCount-$currentClient;
	$estimatedRemainingHours = ($elapsedHours/$currentClient)*$remainingClients;
	$estimatedEndTime = $endTime.AddHours($estimatedRemainingHours);
	$endTimeFormatted = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($estimatedEndTime, 'Eastern Standard Time')).ToString("hh:mm:ss ExT");
	Write-Output ("==> Processed client '{0}' ({1} of {2}). Estimated completion time: {3}." -f $tenantId,$currentClient,$clientCount,$endTimeFormatted);
}
# https://github.com/projectkudu/kudu/wiki/REST-API
Write-Output ("Finishing {0}." -f [System.IO.Path]::GetFileNameWithoutExtension($PSCmdlet.MyInvocation.InvocationName));
