<#
.Synopsis
Approve pending deployment requests.

.Description
The Approve-PendingReleases script approves pending deployment requests for -TargetStage in -Release.

This script invokes Approve-ReleaseDeployments to do the actual processing.

.Parameter TargetStage
This is the target stage for the deployments.

.Parameter Release
This is the release to use.

.PARAMETER LaunchUrl
This launches the URL for each approved release.

.Example
Approve-PendingReleases;

This approves pending releases for stage QAT in release 9.5 (the default).

.Example
Approve-PendingReleases UAT 9.2;

This approves pending releases for stage QAT in release 9.2.

.Example
Approve-PendingReleases -TargetStage PRD -WhatIf;

This shows the deployments requesting approval for stage PRD in release 9.5.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$false,Position=1)]
	[ValidateSet('QAT','UAT','PRF','DMO','STG','PRD')]
	[string]$TargetStage = 'QAT',
	[Parameter(Mandatory=$false,Position=2)]
	[ValidatePattern("^[0-9]+\.[0-9]+$")]
	[string]$Release = '9.5',
	[switch]$LaunchUrl
)
Begin
{
	Write-Verbose "Start Begin{}";
	Push-Location "C:\EYdev\devops\pipelines";
	$filter = "-R{0}" -f $Release;
}
Process
{
	Write-Verbose "Start Process{}";
	Approve-ReleaseDeployments -TargetStage $TargetStage -Filter $filter -IgnoreQat -LaunchUrl:$LaunchUrl -WhatIf:$WhatIfPreference;
	Write-Verbose "Finish Process{}";
}
End
{
	Write-Verbose "Start End{}";
	Pop-Location;
}
