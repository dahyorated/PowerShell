Function Initialize-Script
{
	<#
	.Synopsis
	Initialize the invoking script.

	.Description
	This initialize the invoking script.
	- Set $global:IsVerbose to $true if the -Verbose switch was used.
	- Set $global:org to the Azure DevOps organization URL.
	- Set $global:project to the "Global Tax Platform" project.

	.Parameter MyInvocation
	This is the invoker's invocation context.

	.Example
	Initialize-Script $PSCmdlet.MyInvocation;

	This initializes the invoking script.

	#>
	[CmdletBinding()]
	param(
		$MyInvocation
	)
	if ($MyInvocation.BoundParameters["Verbose"].IsPresent)
	{
		[bool]$global:isVerbose = $True;
	}
	else
	{
		[bool]$global:isVerbose = $False;
	}
	if ($isVerbose) {
		Write-Output "Parameter Values";
		foreach($key in $MyInvocation.BoundParameters.Keys)
		{
			Write-Output ("`t-$($key)" + ' = ' + $MyInvocation.BoundParameters[$key])
		}
	}
	# Add $PSScriptRoot to PATH if needed.
	$pathContents = $ENV:PATH -split ';';
	if ($pathContents -contains $PSScriptRoot)
	{
		Write-Verbose "Path is ready!";
	}
	else
	{
		Write-Verbose ("Adding '{0}' to `$ENV:PATH" -f $PSScriptRoot);
		$ENV:PATH = "{0};{1}" -f $PSScriptRoot,$ENV:PATH;
		$registryPath = 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment';
		Set-ItemProperty -Path $registryPath -Name PATH –Value $ENV:PATH;
	}
	$global:org = "https://eyglobaltaxplatform.visualstudio.com/";
	$global:project = "Global Tax Platform";
}
