Function Get-CurrentLineNumber
{
	<#
	.Synopis
	Returns the current PowerShell script line number.

	.Description
	The Get-CurrentLine function returns the current PowerShell script line number.
	#>
	[CmdletBinding()]
	param(

	)
	$MyInvocation.ScriptlineNumber
}
