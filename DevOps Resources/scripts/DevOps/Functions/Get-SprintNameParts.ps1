Function Get-SprintNameParts
{
	<#
	.Synopsis
	Get the parts of a standard-conforming sprint name.

	.Description
	This gets the parts of a standard-conforming sprint name.

	.Parameter IterationName
	This is a standard-conforming iteration name.

	.Outputs
	If the -IterationName is standard-conforming, the output is a string array with four parts:
	- "PI"
	- PI number
	- "Sprint" or "IP"
	- Sprint number or "Sprint"

	#>
	[CmdletBinding()]
	param(
	[string]$IterationName
	)
	$matches = [Regex]::Match("$IterationName","^(PI)[ ]*([0-9]*)[ ]*(Sprint|IP)[ ]*(Sprint|[0-9]*)$");
	if ($matches.Groups.Count -ne 5)
	{
		$errorMessage = "Badly named iteration '$IterationName'; terminating script.";
		Write-Error $errorMessage;
		Write-Host "##vso[task.logissue type=error]$($errorMessage)";
		Exit 1;
	}
	$sprintNameParts =@($matches.Groups[1].Value,$matches.Groups[2].Value,$matches.Groups[3].Value,$matches.Groups[4].Value);
	return $sprintNameParts;
}
