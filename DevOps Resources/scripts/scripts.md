[[_TOC_]]

# scripts Folder
This folders contains the scripts:
- Used to manage the export of all pipeline objects
- Used to support the management of the CTP release pipelines (*Future*) 

Scripts should be named using the Microsoft standard for names. See [Approved Verbs for PowerShell Commands](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7).

## Folder Structure
This folders with the scripts folder are:
- [Demos](./Demos/Demos.md)
- [DevOps](./DevOps/DevOps.md)
- [OneTime](./OneTime/OneTime.md)
- [Tests](./Tests/Tests.md)

## Major Scripts

### Export-AllDefinitions
This script exports pipeline components that are newer than those already in the [pipelines](../pipelines/pipelines.md) folder.
This script uses the [DevOps Module](#devops) and these scripts:
- [Export-BuildDefinitions.ps1](./Export-BuildDefinitions.ps1)
- [Export-ReleaseDefinitions.ps1](./Export-ReleaseDefinitions.ps1)
- [Export-VariableGroups.ps1](./Export-VariableGroups.ps1)

### Get-ReleaseDefinitionStatusRest
This creates a CSV file with the current status of all release definitions found in the specified Azure DevOps path.
The CSV file contains one line per release definition.
The information include the release name and deployment date/time for the most recent successful deployment in each environment. 
