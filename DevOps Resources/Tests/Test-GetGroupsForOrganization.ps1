[CmdletBinding()]
param()
Push-Location C:\EYdev\devops\scripts;
Import-Module .\DevOps -Force;
Initialize-Script -MyInvocation $PSCmdlet.MyInvocation;
$authHeader = New-AuthorizationHeader -token $env:SYSTEM_ACCESSTOKEN;
$groups = Get-GroupsForOrganization -AuthHeader $authHeader | Sort-Object principalName;
[array]$releaseApprovers = $groups.value | Where-Object displayName -like 'Release *';
Write-Output ("Found {0} release approvers." -f $releaseApprovers.Count);
foreach ($releaseApprover in $releaseApprovers)
{
	Write-Output ("==> {0}" -f $releaseApprover.principalName);
}
Pop-Location;
