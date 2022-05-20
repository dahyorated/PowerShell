<#
.Synopsis
Set diagnostics settings for an Azure Event Grid Topic to a Log Analytics Workspace.

.Description
The Set-DiagnosticsSettingsForEventGrid script sets diagnostics settings for the -EventGridTopicName Azure Event Grid Topic to the -WorkspaceName Log Analytics Workspace.

.Parameter ResourceGroupName
This is the resource group containing the event grid and log analytics workspace.

.Parameter EventGridTopicName
The name of the Event Grid Topic

.Parameter WorkspaceName
The name of the Log Analytics workspace

.Example

Set-DiagnosticsAndDeadletterForEventGrid.ps1 -ResourceGroupName "GT-WEU-GTP-CORE-DEV-RSG" -EventGridTopicName "EUWDGTP005ETN01" -WorkspaceName "euwdgtp005law01";

#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
param(
	[Parameter(Mandatory = $true)]
	[string]$ResourceGroupName,
	[Parameter(Mandatory = $true)]
	[string] $EventGridTopicName,
	[Parameter(Mandatory = $true)]
	[string] $WorkspaceName
	)

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;

if ($isVerbose) {
	Write-NameAndValue "resourceGroupName" $ResourceGroupName;
	Write-NameAndValue "eventGridTopicName" $EventGridTopicName;
	Write-NameAndValue "workspaceName" $WorkspaceName;
}
Write-Output "Start Set-DiagnosticsAndDeadletterForEventGrid";
$eventGrid = Get-AzEventGridTopic -ResourceGroupName $ResourceGroupName -Name $EventGridTopicName;
$resourceId = $eventGrid.Id;
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName;
if ($PSCmdlet.ShouldProcess($EventGridTopicName,"Set-DiagnosticsAndDeadletterForEventGrid"))
{
	Set-AzDiagnosticSetting -Name service `
		-ResourceId $resourceId `
		-Category DeliveryFailures,PublishFailures -MetricCategory AllMetrics -Enabled $true `
		-WorkspaceId $workspace.ResourceId;
}
Write-Output "Finish Set-DiagnosticsAndDeadletterForEventGrid";
