Push-Location "C:\EYdev\devops\scripts\Tests";
#..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1 -VariableGroups @('Versioning_Test2') -Verbose;
#..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1 -VariableGroups @('Versioning_Test2') -NoUpdate -Verbose;
#..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1 -VariableGroups @('Versioning_Test2') -SaveUpdateJson -NoUpdate -Verbose;
#..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1 -VariableGroups @('Versioning_Test','Versioning_Test2');
#..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1 -VariableGroups @('Versioning_Test','Versioning_Test2') -SaveUpdateJson -NoUpdate;
#..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1 -NoUpdate;
..\OneTime\Convert-VariableGroupsRemoveHotFix.ps1;
Pop-Location
