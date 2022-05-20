Push-Location "C:\EYdev\test";
$env:AGENT_TOOLSDIRECTORY = "C:\EYdev\test";
$env:IS_PSCX_ARCHIVE = $true;
. $PSScriptRoot\Get-DevOpsFromContainer.ps1;
Pop-Location;
