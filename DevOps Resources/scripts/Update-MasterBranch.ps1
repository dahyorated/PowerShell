[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[string]$CommitMessage = "Updates from ",
	[Parameter(Mandatory=$False)]
	[string]$CommitMessageFile,
	[Parameter(Mandatory=$False)]
	$UserEmail = "Brad.Fiedlander@ey.com",
	[Parameter(Mandatory=$False)]
	$UserName = "Brad Friedlander"
)
$rootFolder = Split-Path "$PSScriptRoot";
Push-Location "$rootFolder";
Write-Output "Executing 'git commit -a' in '$PWD' with message '$CommitMessage'";
git config --global user.email "$UserMail";
git config --global user.name "$UserName";
git add .;
git status;
if ([string]::IsNullOrWhiteSpace($CommitMessageFile))
{
	git commit -a -m "$CommitMessage";
}
else
{
	git commit -a -F "$CommitMessageFile";
}
git push;
Pop-Location;
