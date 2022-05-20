Function Write-NameAndValue
{
	<#
	.Synopsis
	Write a variable name and value in a standard format.

	.Description
	The Write-NameAndValue writes the -Name variable name and -Value variable value in a standard format.

	The standard format is: "<<-Name>>: <<-Value>>".

	.Parameter Name
	This is the name of the variable.

	.Parameter Value
	This is the string value of the variable.
	#>
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$Name,
		[Parameter(Mandatory=$false,Position=1)]
		[string]$Value
	)
	Write-Output ("{0}: {1}" -f $name,$value);
}
