<#
.SYNOPSIS
Update the target and rollback spreadsheet for a release.

.DESCRIPTION
This creates or updates the target and rollback spreadsheet for the release specified by -Release.

.PARAMETER Release
This is the release number.It has the form "9.9" for a normal release or "9.9.9" for a hot fix release.

.EXAMPLE
Update-TargetAndRollback -Release '8.4'

This updates the spreadsheet for the release '8.4'.

.EXAMPLE
Update-TargetAndRollback -Release '8.4.1'

This updates the spreadsheet for the hot fix release '8.4.1'.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$Release = '8.4'
)
$releaseParts = $Release -split '\.';
if ($releaseParts.Count -eq 1 -or $releaseParts.Count -gt 3)
{
	throw "'$Release' is not a valid release number."
}
Get-TargetAndRollback -Excel -Release $Release;
$source = ".\Release {0} Target And Rollback.xlsx" -f $Release;
$target = "{0}\EY\Global Tax Platform - DevOps\Deployment\PI{1}\Release {2}\" -f $ENV:USERPROFILE,$releaseParts[0],$Release;
Copy-Item "$source" "$target";
