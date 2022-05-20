Push-Location "C:\EYdev\devops\pipelines";
#New-ReleaseBranch -BranchName 'PI42.1';
#New-ReleaseBranch -BranchName 'PI42.1' -RepositoryName 'BoardWalkRepo';
#New-ReleaseBranch -RepositoryName 'APIM' -BranchName 'PI9.5';
New-ReleaseBranch -RepositoryName 'alteryx' -BranchName 'PI10.3';
#New-ReleaseBranchesAllRepositories -BranchName 'PI42.99' -WhatIf;
Pop-Location;
