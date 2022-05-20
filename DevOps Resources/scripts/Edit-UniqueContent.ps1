<#
.Synopsis
Edit the content of the file by sorting lines in ascending order and eliminating all duplicates.
.Description
The Edit-UniqueContent script edits the content of the -Source file by sorting lines in ascending order and eliminating all duplicates.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$True,Position=1)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Leaf) )
		{
			throw "File '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$Source
)
$content = Get-Content -Path $Source;
if ($PSCmdlet.ShouldProcess($Source))
{
	$content |
		Sort-Object -Unique |
		Out-File -FilePath $Source -Force;
		$message = "Sorting unique on '{0}'" -f $Source;
		Write-Output $message;
}
