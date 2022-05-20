$ENV:RELEASE_REQUESTEDFOREMAIL = "Brad.Friedlander@ey.com";
$ENV:RELEASE_REQUESTEDFOR = "Brad Friedlander";
$ENV:SYSTEM_DEFAULTWORKINGDIRECTORY = "C:\EYdev\test\LocalRepo";
Get-ChildItem $ENV:SYSTEM_DEFAULTWORKINGDIRECTORY -Force -Recurse | Foreach-Object {Remove-Item $_.FullName -Force -Recurse};
#C:\EYdev\devops\scripts\InlineScripts\git-clonev1.ps1;
C:\EYdev\devops\scripts\InlineScripts\git-clonev3.ps1;
