[[_TOC_]]

# ReleaseDefinitions Folder
This folder contains the release definitions extracted from "\CTP" and child folders.

The content is managed by the `Export-AllDefinitions` command.
- __Example 1__ is the normal version used each day. This does the extract and update the repository.
- __Example 2__ is used if you want a local copy and do not want to update the repository.

__Example 1__
```PowerShell
Export-AllDefinitions -UpdateGit;
```

__Example 2__
```PowerShell
Export-AllDefinitions -Force;
```
