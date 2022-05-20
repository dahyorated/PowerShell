Function Get-NonEmptyChoice()
{
	<#
	.Synopsis
	Get the first non-empty choice of the two parameters.

	.Description
	This gets the first non-empty choice of the two parameters.

	.Parameter PossibleEmptyValue
	This is the value that is used if it is not an empty or null string.

	.Parameter DefaultValue
	This is the value that is used if -PossibleEmptyValue is an empty or null string.

	.Outputs
	This is the first non-empty choice of the two parameters.

	.Example
	$nonEmptyChoice = Get-NonEmptyChoice 'a' 'x';

	This sets $nonEmptyChoice to 'a' since the first parameter is not an empty or null string.

	.Example
	$nonEmptyChoice = Get-NonEmptyChoice '' 'x';

	This sets $nonEmptyChoice to 'x' since the first parameter is an empty string.

	#>
	[CmdletBinding()]
	param(
	[string]$PossibleEmptyValue,
	[string]$DefaultValue
	)
	Write-Verbose "ENV: '$($PossibleEmptyValue)'";
	Write-Verbose "DEF: '$($DefaultValue)'";
	if ([string]::IsNullOrWhiteSpace($PossibleEmptyValue))
	{
		return $DefaultValue;
	}
	else
	{
		return $PossibleEmptyValue;
	}
}
