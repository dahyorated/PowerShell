[[_TOC_]]

# OneTime Folder
This contains scripts that are used once. This includes scripts used for migrations and conversions.

All scripts will need to use the following construct to include the DevOps module.

```PowerShell
Import-Module -Name $PSScriptRoot\..\DevOps -Force -Verbose:$false;
Initialize-Script $PSCmdlet.MyInvocation;
```
