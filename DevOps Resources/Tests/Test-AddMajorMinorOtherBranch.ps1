Push-Location C:\EYdev\devops\scripts;
$env:BUILD_SOURCEBRANCH = "refs/heads/develop";
$env:BUILD_SOURCEBRANCHNAME = 'develop';
$env:BUILD_DEFINITIONNAME = 'Test CI';
$env:SYSTEM_TEAMPROJECT = 'Global Tax Platform';
$env:SYSTEM_TEAMFOUNDATIONSERVERURI = 'https://eyglobaltaxplatform.visualstudio.com';
Add-MajorMinorOtherBranch.ps1 -Release 9.4 -UseTest -Verbose;
Pop-Location;
