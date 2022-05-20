Function Write-AsJson
{
	<#
	.Synopsis
	Convert the provided object to JSON and writes the result to standard output.

	.Description
	The Write-AsJson script converts the -CustomObject object to JSON and writes the result to standard output.

	.Parameter CustomObject
	This is the object to be converted to JSON.

	.Parameter Compress
	If specified, the output is compressed to a single line (i.e., no line breaks).
	#>
	[CmdletBinding()]
	param(
		[PSCustomObject]$CustomObject,
		[switch]$Compress
	)
	Write-Output ($CustomObject | ConvertTo-Json -Depth 100 -Compress:$Compress);
}
