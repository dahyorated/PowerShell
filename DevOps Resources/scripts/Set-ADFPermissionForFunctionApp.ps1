<#
.Synopsis
Grant contributor access to a Datafactory

.Description
Grant the contributor access to a datafactory from a functionC\BuildScripts\VSTSRMScripts\VSTSRMScripts").

.Parameter subscriptionId
This is the ID of the subscription containing the function and data factory;

.Parameter ResourceGroupName
This is the resource group containing -FunctionName.

.Parameter FunctionAppName
This is the Function App

.Parameter DataFactoryName
This is the name of the Data Factory

.Example
Set-ADFPermissionForFunctionApp.ps1 -SubscriptionId "5aeb8557-cab7-41ac-8603-9f94ad233efc" -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -FunctionAppName  "EUWDGTP005AFA06" -DataFactoryName  "EUWDGTP005DFA02";

#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
param(
	[Parameter(Mandatory = $true)]
	[string] $SubscriptionId,
	[Parameter(Mandatory = $true)]
	[string] $ResourceGroupName,
	[Parameter(Mandatory = $true)]
	[string] $FunctionAppName,
	[Parameter(Mandatory = $true)]
	[string] $DataFactoryName
)

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

if (-not (get-module -ListAvailable -name "Az.Functions")) {
	install-packageprovider -name nuget -force -scope currentuser
	install-module -name "Az.Functions" -force -scope currentuser
}
if (-not (get-module -ListAvailable -name "Az.Resources")) {
	install-packageprovider -name nuget -force -scope currentuser
	install-module -name "Az.Resources" -force -scope currentuser
}

Write-Output "Starting Set-ADFPermissionForFunctionApp.ps1"

if ($isVerbose) {
		Write-NameAndValue "subscriptionId" $subscriptionId;
		Write-NameAndValue "ResourceGroupName" $ResourceGroupName;
		Write-NameAndValue "FunctionAppName" $FunctionAppName;
		Write-NameAndValue "DataFactoryName" $DataFactoryName;
}

$functionApp  = Get-AzFunctionApp -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -Name $FunctionAppName;
$dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Name $DataFactoryName;
$roleDefinitionId = (Get-AzRoleDefinition -Name Contributor).Id;

$objectId  = $functionApp.IdentityPrincipalId;
if ($objectId -eq $null) {
	write-verbose "Creating MSI for function App";
	$update = Update-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -IdentityType SystemAssigned;
	$objectId = $update.IdentityPrincipalId;
	#sleep 30 seconds for the principal to exist (per previous failure an MSFT guidance)
	Sleep 30;
}

$scope = $dataFactory.DataFactoryId;

Write-Verbose "ObjectId: $objectId RoleDefinitionId $roleDefinitionId Scope $scope";

try {
	$assignment = New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionId $roleDefinitionId -Scope $scope -ErrorAction Stop;
	Write-verbose $assignment;
	}
catch
{
	if ($_.Exception.Message -eq "The role assignment already exists.")
	{
		Write-Output "Assignment already exists";
	}
	else
	{
		$message = "Error: {0}" -f $_.Exception.Message;
		Stop-ProcessError -errorMessage $message;
	}
}

Write-Output "Finished Set-ADFPermissionForFunctionApp.ps1";
