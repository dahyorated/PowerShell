[CmdletBinding()]
param(

)
$registryPath = 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment';
$path = (Get-ItemProperty -Path $registryPath -Name PATH).Path;
$pathContents = $path -split ';';
Write-Output "Contents of `$ENV:PATH ==>";
foreach ($pathItem in $pathContents)
{
	Write-Output $pathItem;
}
