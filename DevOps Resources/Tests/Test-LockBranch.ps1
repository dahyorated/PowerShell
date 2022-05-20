Push-Location "C:\EYdev\devops\pipelines";
Lock-Branch -BranchName 'develop' -RepositoryName 'BoardWalkRepo';
Read-Host -Prompt "check branch, then press any key to continue";
Lock-Branch -BranchName 'develop' -RepositoryName 'BoardWalkRepo' -Unlock;
Pop-Location;
