# Version that works on laptop
Write-Output "Start git clone";
git config --global user.email "$ENV:RELEASE_REQUESTEDFOREMAIL";
git config --global user.name "$ENV:RELEASE_REQUESTEDFOR";
git config --global -l;
Push-Location $ENV:SYSTEM_DEFAULTWORKINGDIRECTORY;
$repoUrl = "https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_git/Configuration";
Write-Output ("Repo URL: {0}" -f $repoUrl);
$localRepo = "{0}/Configuration" -f $ENV:SYSTEM_DEFAULTWORKINGDIRECTORY;
try
{
	Write-Output "git -c https.extraheader=""Authorization: bearer $ENV:SYSTEM_ACCESSTOKEN"" clone $repoUrl 2>&1;";
	$results = git -c https.extraheader="Authorization: bearer $ENV:SYSTEM_ACCESSTOKEN" clone $repoUrl 2>&1;
}
catch
{
	Write-Output "Exception:";
	Write-Output $_.Exception.Message;
	Write-Output "Exception Details:";
	Write-Output $_;
	Write-Output "##vso[task.logissue type=error]$($_.Exception.Message)";
	Pop-Location;
	Exit;
}
Write-Output "End git clone";
if (-not (Test-Path $localRepo -PathType Container))
{
	Write-Output ("Folder '{0}' does not exist." -f $localRepo);
	Exit 1;
}
Set-Location $localRepo;
Add-Content -Value $(get-date) -Path .\test.txt;
git add .;
git status;
Write-Output "git commit -m ""made changes"";";
git commit -m "made changes";
try
{
	Write-Output "git -c https.extraheader=""Authorization: bearer $ENV:SYSTEM_ACCESSTOKEN"" push 2>&1;";
	$results = git -c https.extraheader="Authorization: bearer $ENV:SYSTEM_ACCESSTOKEN" push 2>&1;
}
catch
{
	Write-Output "Exception:";
	Write-Output $_.Exception.Message;
	Write-Output "Exception Details:";
	Write-Output $_;
	Pop-Location;
	Write-Output "##vso[task.logissue type=error]$($_.Exception.Message)";
	Exit 1;
}
Write-Output "End git clone";
Get-ChildItem $ENV:SYSTEM_DEFAULTWORKINGDIRECTORY;
Pop-Location;
