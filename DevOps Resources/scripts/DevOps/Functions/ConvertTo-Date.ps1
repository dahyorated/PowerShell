<#
.Synopsis
Convert any string with a valid date format to a [DateTime] object.

.Description
This convert any string with a valid date format to a [DateTime] object.
If the string does not have a valid date, it returns '1900-01-01'.

.Parameter dateIn
This is a string containing a valid date format.

.Example
ConvertTo-Date '11/2020'

This returns '2020-11-01'.

.Example
ConvertTo-Date '1x/2020'

This returns '1900-01-01'.

#>
Function ConvertTo-Date
{
	[CmdletBinding()]
	param(
		[string]$dateIn
	)
	[DateTime]$dateOut = [DateTime]'1900-01-01';
	$converted = [DateTime]::TryParse($dateIn,[ref]$dateOut);
	return $dateOut;
}
