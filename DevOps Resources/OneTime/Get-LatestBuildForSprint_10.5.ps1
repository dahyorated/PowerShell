Push-Location C:\EYdev\devops\pipelines;
Get-LatestBuildsForSprint -Sprint 10.4 -BranchName 'Release/PI10.4' -Release 10.5;
Get-LatestBuildsForSprint -Sprint 10.5 -BranchName 'develop' -Release 10.5;
Pop-Location;
