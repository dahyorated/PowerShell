[CmdletBinding()]
param(

)
Push-Location C:\EYdev\devops\scripts;
Import-Module -Name .\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
Wait-JobCompletion -jobId 559133 -Verbose;
Pop-Location;
