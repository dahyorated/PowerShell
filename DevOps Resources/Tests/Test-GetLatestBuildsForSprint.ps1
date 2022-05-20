Push-Location C:\EYdev\devops\pipelines;
#Get-LatestBuildsForSprint -Sprint 9.6 -BranchName 'develop' -Release 10.3;
#Get-LatestBuildsForSprint -Sprint 10.1 -BranchName 'Release/PI10.1' -Release 10.3;
#Get-LatestBuildsForSprint -Sprint 10.2 -BranchName 'Release/PI10.2' -Release 10.3;
#Get-LatestBuildsForSprint -Sprint 10.3 -BranchName 'develop' -Release 10.3;
Get-LatestBuildsForSprint -Sprint 10.6 -BranchName 'develop' -Release 10.6;
Pop-Location;
