Write-Output "Setting 'HKLM\...\Environment' to `$ENV:PATH";
$registryPath = 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment';
Set-ItemProperty -Path $registryPath -Name PATH –Value $ENV:PATH;
