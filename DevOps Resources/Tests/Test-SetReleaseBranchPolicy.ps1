Push-Location "C:\EYdev\devops\scripts";
#Set-ReleaseBranchPolicy -BranchName "PI9.5" -WhatIf;
#Set-ReleaseBranchPolicy -BranchName "PI9.5";
#Set-ReleaseBranchPolicy -RepositoryName 'alteryx' -BranchName "PI10.3" -WhatIf;
Set-ReleaseBranchPolicy -RepositoryName 'alteryx' -BranchName "PI10.4";
#Set-ReleaseBranchPolicy -BranchName "PI10.4";
Pop-Location;
