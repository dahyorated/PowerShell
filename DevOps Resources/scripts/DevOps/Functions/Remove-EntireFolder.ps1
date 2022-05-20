Function Remove-EntireFolder
{
<#
.Synopsis
Delete a folder and all of its content.

.Decription
The Remove-EntireFolder function deletes the -RootFolder folder and all of its content.

.Parameter RootFolder
This is the folder to be deleted.

.Example
Remove-EntireFolder -RootFolder ".\Xyzzy";

This removes the ".\Xyzzy" folder and all of its contents including hiddent and read-only file and all subfolders.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
param(
	[Parameter(Mandatory=$true)]
	[ValidateScript({
		if(!($_ | Test-Path -PathType Container))
		{
			throw "Folder '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$RootFolder
)
Get-ChildItem $RootFolder -Force -Recurse | Foreach-Object {Remove-Item $_.FullName -Force -Recurse};
Remove-Item $RootFolder;
}
