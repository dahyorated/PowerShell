[CmdletBinding()]
param (
	[Parameter(Mandatory=$False)]
	[string]$StageName = "euwdev",
	[Parameter(Mandatory=$False)]
	[string]$resourceGroupName = "GT-WEU-GTP-CORE-DEV-RSG",
	[Parameter(Mandatory=$False)]
	[string]$RolePurpose = "App Service Plan for Import Service"
)

Function Get-LocationFromStage
{
	param(
		[string]$stageName
	)
	$regionPart = $stageName.ToLower().Substring(0,3);
	$location =  switch ($regionPart)
	{
		euw { "westeurope" }
		use { "eastus" }
		default { "" }
	}
	return $location;
}

Function Get-ResourceGroupFromStage
{
	param(
		[string]$stageName
	)
	$regionPart = $stageName.ToLower().Substring(0,3);
	$groupPart = $stageName.ToLower().Replace($regionPart,"");
	Write-Verbose "Getting resource group name for '$($groupPart)' in region '$(Get-LocationFromStage $regionPart)'.";
	$groupName = switch ($regionPart)
	{
		euw { "GT-WEU-GTP-CORE-{0}-RSG" -f $groupPart.ToUpper() }
		use { "GT-EUS-GTP-CORE-{0}-RSG" -f $groupPart.ToUpper()}
		default { $resourceGroupName }
	}  
	return $groupName;
}

$regionName = Get-LocationFromStage $StageName;
Write-Output "Region: '$($regionName)'.";
$resourceGroupName = Get-ResourceGroupFromStage $StageName;
Write-Output "Resource Group Name: '$($resourceGroupName)'.";
# Get the App Service Plan just created
$global:appServicePlans =
	Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Web/serverFarms |
	Where-Object {$_.Tags.ROLE_PURPOSE -like $RolePurpose}
;
$global:appServicePlans;
