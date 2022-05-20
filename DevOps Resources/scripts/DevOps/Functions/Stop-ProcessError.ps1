Function Stop-ProcessError
{
	<#
	.Synopsis
	Process a terminating error message.

	.Description
	The Stop-ProcessError function outputs the error message, logs the error in the pipeline, and exits from PowerShell.

	.Parameter ErrorMessage
	This is the error message to be used.

	.Example
	Stop-ProcessError "A null value for Xyzzy is not supported.";
	#>
	[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
	param(
		[string]$ErrorMessage
	)
	if ($PSCmdlet.ShouldProcess($ErrorMessage))
	{
		Write-Output "$ErrorMessage";
		Write-Output "##vso[task.logissue type=error]$($ErrorMessage)";
		Exit 1;
	}
}
