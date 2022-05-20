Push-Location "C:\EYdev\devops\pipelines";
#Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test') -NoUpdate -Verbose;
#Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test') -NoUpdate;
#Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test2') -NoUpdate -Verbose;
#Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test2') -Verbose;
#Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test','Versioning_Test2');
Update-VariableGroupsReleasesFromDevelop -Release 9.4 -VariableGroups @('Versioning_Test','Versioning_Test2') -NoUpdate;
#Update-VariableGroupsReleasesFromDevelop -Release 9.4 -NoUpdate;
#Update-VariableGroupsReleasesFromDevelop -Release 10.1 -VariableGroups @('Versioning_WidgetService')
Pop-Location
