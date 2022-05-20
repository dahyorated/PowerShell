[[_TOC_]]

- [Introduction](#introduction)
- [Usage](#usage)
- [Folders](#folders)

# Introduction 
This repository is used by the DevOps team to contain the artifacts used to manage the [Global Tax Platform](https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform) project.
The scripts contained in this repository are designed to automate some of the repetitive DevOps functions.

# Usage

## Getting Started
The [scripts](./scripts/scripts.md) folder is assumed to be the root folder for all script executions.
- All internal file references (*i.e.*, those used to manage the script) should be relative to that folder.
- This repository should be cloned to `C:\EYdev\devops`. This handles the few instances where an absolute file reference is needed.
- All other repositories should be cloned as a child of `C:\EYdev`. Current release repositories and location are shown below.

| Repository | Standard Local Path |
| --- | ---|
| `devops` | `C:\EYdev\devops` |
| `APIM` | `C:\EYdev\APIM` |
| `BoardWalkRepo` | `C:\EYdev\BoardWalkRepo` |
| `Global Tax Platform` | `C:\EYdev\GTP` |
| `Global-Tax-Platform.wiki` | `C:\EYdev\Global-Tax-Platform.wiki` |

## Build and Resources
There is no build required. All scripts use the latest versions (unless otherwise noted) of:
- PowerShell
- PowerShell Module Az (not AzureRm)
- AZ CLI
- ImportExcel Required Version 7.0.0

```PowerShell
Import-Module -Name Az;
Import-Module -Name ImportExcel -RequiredVersion 7.0.0;
```

## PATH Setup
The Windows `PATH` variable need to include the scripts folder (*i.e.,* `C:\EYdev\devops\scripts`).

### Global Usage
To use this globally, update `PATH` in the system environment variables. This can be set up by going to:
- `Control Panel\System and Security\System`
- `Advanced Systems Settings`
- `Environment Variables`

Under `User variables for ...`, update `PATH` to add `C:\EYdev\devops\scripts` as the first element.

### One-time Usage
It can also be scoped to the current PowerShell session using this command.
```PowerShell
$ENV:PATH = "{0};{1}" -f "C:\EYdev\devops\scripts",$ENV:PATH;
```

## Security Token
Scripts that require a DevOps security access token get the token from the environment.
```PowerShell
param (
    [Parameter(Mandatory=$false)]
    [string]$Token = ${env:SYSTEM_ACCESSTOKEN}
)
```
This allows the scripts to work when run in a pipeline (under the DevOps SPN) as well as when run locally under a user's personal access token (PAT).

A user's PAT should have `Scopes` set to `Full access`. This can be created or modified in Azure DevOps [Personal Access Tokens](https://eyglobaltaxplatform.visualstudio.com/_usersSettings/tokens).

To use this locally, add `SYSTEM_ACCESSTOKEN` to the system environment variables. This can be set up by going to:
- `Control Panel\System and Security\System`
- `Advanced Systems Settings`
- `Environment Variables`

Under `User variables for ...`, add `SYSTEM_ACCESSTOKEN` with your personal access token as its value.

## PowerShell Naming
PowerShell scripts should conform with the [Approved Verbs for PowerShell Commands](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7).

# Folders
When you add a new folder, the folder must contain a markdown file with the same name as the folder (with `.md` extensions).
- The file should clearly define the usage of the folder.
- [`devops` Repository Folder Tree](#devops-repository-folder-tree) must be updated with the new folder.

 ## devops Repository Folder Tree
- [Demos](./Demos/Demos.md)
- [Deprecated](./Deprecated/Deprecated.md)
- [DevOpsYaml](./DevOpsYaml/DevOpsYaml.md)
- [InlineScripts](./InlineScripts/InlineScripts.md)
- [maintenance](./maintenance/maintenance.md)
- [OneTime](./OneTime/OneTime.md)
- [pipelines](./pipelines/pipelines.md)
    - [BuildDefinitions](./pipelines/BuildDefinitions/BuildDefinitions.md)
    - [ReleaseDefinitions](./pipelines/ReleaseDefinitions/ReleaseDefinitions.md)
    - [TaskGroups](./pipelines/TaskGroups/TaskGroups.md)
    - [VariableGroups](./pipelines/VariableGroups/VariableGroups.md)
- [projects](./projects/projects.md)
- [provisioning](./provisioning/provisioning.md)
- [quotas](./quotas/quotas.md)
- [scripts](./scripts/scripts.md)
    - [DevOps](./scripts/DevOps/DevOps.md)
- [TenantSubscriptions](./TenantSubscriptions/TenantSubscriptions.md)
- [Tests](./Tests/Tests.md)
- [T-SQL](./T-SQL/T-SQL.md)
- [users](./users/users.md)
- [witadmin](./witadmin/witadmin.md)
- [yamlpipelines-poc](./yamlpipelines-poc/yamlpipelines-poc.md)
