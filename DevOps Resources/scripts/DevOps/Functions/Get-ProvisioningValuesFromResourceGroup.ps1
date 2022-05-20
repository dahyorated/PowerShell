Function Get-ProvisioningValuesFromResourceGroup
{<#
.Synopsis
	This Function will take a Resoure Group as input and output a custom object with the appropriate values that can be derived for resources in that group
	this can be used for provisioning new objects or validating correct settings for existing objects
.Outputs
The function returns an object. This is an example:
[PSCustomObject]@{
  DeploymentId = "GTP005"
  AnsibleEnvironment = "Development"
}

	DeploymentId is the Deployment ID for an Environment - this is used for Meaningful, Ansible and associating the environment for Azure Alerts
	AnsibleEnvironment is the Environment value to use in provisioning to Ansible.  (These don't exactly match GTP environment names)
#>
	[CmdletBinding()]
	param (
		[string]$ResourceGroup
	)

	[PSCustomObject] $ret = @{};
	
	$stageName = switch($ResourceGroup)
	{
		{('GT-WEU-GTP-CORE-DEV-RSG','GT-EUS-GTP-CORE-DEV-RSG','GT-WEU-GTP-TENANT-DEV-RSG','GT-EUS-GTP-TENANT-DEV-RSG') -contains $_} 
			{
				$ret.DeploymentId =  'GTP005';
				$ret.AnsibleEnvironment = 'Development';
				break;
			}
		{('GT-WEU-GTP-CORE-QA-RSG','GT-WEU-GTP-TENANT-QA-RSG' ) -contains $_}
		{
				$ret.DeploymentId =  'GTP007'
				$ret.AnsibleEnvironment = 'QA'
			}
		{('GT-WEU-GTP-CORE-UAT-RSG','GT-WEU-GTP-TENANT-UAT-RSG') -contains $_} 
		{
				$ret.DeploymentId =  'GTP014'
				$ret.AnsibleEnvironment = 'UAT'
			}
		{('GT-WEU-GTP-CORE-PERF-RSG','GT-WEU-GTP-TENANT-PERF-RSG') -contains $_} 
			{
				$ret.DeploymentId =  'GTP012'
				$ret.AnsibleEnvironment = 'PERF'
			}
		{('GT-WEU-GTP-CORE-SHR-RSG','GT-EUS-GTP-CORE-SHR-RSG') -contains $_} 
		  {
			  $ret.DeploymentId =  'GTPSHR'
			  #AnsibleEnvironment not specific
				 }
		{('GT-WEU-GTP-CORE-STG-RSG', 'GT-EUS-GTP-CORE-STG-RSG','GT-EUS-GTP-TENANT-STG-RSG','GT-WEU-GTP-TENANT-STG-RSG') -contains $_}
		{
				$ret.DeploymentId =  'GTP020'
				$ret.AnsibleEnvironment = 'Staging'
			}
		{('GT-WEU-GTP-CORE-PROD-RSG','GT-EUS-GTP-CORE-PROD-RSG','GT-EUS-GTP-TENANT-PROD-RSG','GT-WEU-GTP-TENANT-PROD-RSG') -contains $_}
		{
				$ret.DeploymentId =  'GTP018'
				$ret.AnsibleEnvironment = 'Production'
			}
	
			{('GT-WEU-GTP-CORE-DEMO-RSG','GT-WEU-GTP-TENANT-DEMO-RSG') -contains $_} 
			{
				$ret.DeploymentId =  'GTP035'
				$ret.AnsibleEnvironment = 'DEMO'
			}

		default {throw "Unsupported"}
	}
	return $ret;
}
