Function New-AuthorizationHeader
{
	<#
	.Synopsis
	Create an Azure DevOps authorization header.

	.Description
	The New-AuthorizationHeader function creates an Azure DevOps authorization header using the provided -token parameter.
	The header is a Basic authorization token.

	.Parameter token
	This is an Azure DevOps PAT (Personal Access Token).

	.Outputs
	This returns the basic authorization header. It also sets $global:AuthHeader to the basic authorization header.

	.Example
	$header = New-AuthorizationHeader $token;

	This returns the header for the provided token.

	#>
	[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
	param(
		[string]$token
	)
	if ([string]::IsNullOrWhiteSpace($token))
	{
		$errorMessage = "Authentication token is null or whitespace.";
		Write-Error "$errorMessage";
		Write-Output "Ensure the environment variable 'SYSTEM_ACCESSTOKEN' contains a valid token.";
		Write-Output "##vso[task.logissue type=error]$($ErrorMessage)";
		Exit 1;
	}
	Write-Verbose "Initialize authentication header using token '$($token)'";
	$encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($token)"));
	if ($PSCmdlet.ShouldProcess("New-AuthorizationHeader"))
	{
		$global:AuthHeader = @{authorization = "Basic $encodedToken"};
	}
	return $global:AuthHeader;
}
