[[_TOC_]]

# Tests Folder
This folder contains tests for the PowerShell scripts in the [scripts](../scripts.md) folder.

The convention for a test script name is `Test-<<Script Name>>.ps1` where `<<ScriptName>>` is the name of the script with all "-" characters removed. For example the test script for `New-TenantDatabase.ps1` is named `Test-NewTenantDatabase.ps1`

All test scripts should have this structure. `XXX` is the desired starting folder. Common starting folders are:
- pipelines
- provisioning

```PowerShell
Push-Location "C:\EYdev\devops\XXX";
<<ScriptName>> <<Parameters>>;
Pop-Location;
```
