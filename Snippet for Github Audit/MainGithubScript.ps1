param (

    [string]$PAT = "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", # This token MUST have admin rights
    [string]$OrgName = "TBCTDevelopment",
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

#TODO: Mark branches as "inactive" based on same calculations for repos
# Note the code type for each repo, if it is provided
# Note number of issues
# Is the repo archived
# Provide language breakdown of each repository
# Provide type of build: container, etc.
# Maybe the license type??

# code for promptless login:

cls

class RepoFileData {
   
   [string]$Type
   [string]$Contents
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Install the module if not present
Install-Module -Name PowerShellForGitHub

Import-Module PowerShellForGitHub

# Define clear text string for username and password
[string]$userName = 'NotNeeded'
[string]$userPassword = $PAT

# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force


#Create the credential
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Set-GitHubAuthentication -Credential $credObject -SessionOnly -ErrorAction SilentlyContinue

# Access the Organizational Repo
$OrganizationalRepos = Get-GitHubRepository -OrganizationName $OrgName

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}

Write-Host There are a total of $OrganizationalRepos.Count repositories.

Write-Host ""
Write-Host "**************" 
Write-Host "Organization Secrets"
Write-Host "---------------"

$OrgSecrets = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/actions/secrets') -Method GET -Headers $headers

for ( $index = 0; $index -lt $OrgSecrets.total_count; $index++) {

    Write-Host Secret: $OrgSecrets.secrets[$index]
}
    
Write-Host ""

Write-Host "**************" 
Write-Host "Organization Repos and Branches"
Write-Host "---------------"

Write-Host ""    

$ReposWithWorkflows = 0

foreach ($repo in $OrganizationalRepos) {


    Write-Host "**************"    
    Write-Host "Repository Name:" $repo.name    

    Write-Host "Repository type:" $repo.visibility
    Write-Host "Repository archived:" $repo.archived
    Write-Host "Repository disabled:" $repo.disabled
    Write-Host "Repository permissions:" $repo.permissions
    Write-Host "Repository last updated " $repo.updated_at
    Write-Host Owner: $repo.owner.UserName

    $UpdatedAt = [datetime]$repo.updated_at
    $CurrentDate = Get-Date
    $PreviousDate = $CurrentDate.AddMonths(-$MonthsToDeclareInactiveRepo)

    if ($UpdatedAt -gt $PreviousDate)
    {
        Write-Host "Repo is active."
    }
    else
    {
        Write-Host "Repo is inactive."
    }

    Write-Host "---------------"

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Languages"
    Write-Host "-------------- "
    $Languages = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/languages') -Method GET -Headers $headers
    $Languages | Format-Table

    Write-Host ""
    #Getting Contributors on Each Repository
    Write-Host "**************" 
    Write-Host "Repository Contributors"
    Write-Host "-------------- "
    $Contributors = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contributors') -Method GET -Headers $headers
    $contributors 
    Write-Host ""

    #Getting Teams attached to each Repository
    Write-Host "**************" 
    Write-Host "Repository Teams"
    Write-Host "---------------"
    $repoteams = Get-GitHubTeam -OwnerName $OrgName -RepositoryName $repo.name
    $repoteams
    Write-Host "---------------"

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Tags"
    Write-Host "---------------"

    $RepoTags = Get-GitHubRepositoryTag -OwnerName $OrgName -RepositoryName $repo.name
    $RepoTags | Format-Table
    $RepoBranches = Get-GitHubRepositoryBranch -OwnerName $OrgName -RepositoryName $repo.name

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Status"
    Write-Host "---------------"

    Write-Host Disabled: $repo.disabled
    Write-Host Archived: $repo.archived
    Write-Host Visibility: $repo.visibility
    

    $Artifacts = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/artifacts') -Method GET -Headers $headers
    Write-Host Number of Artifacts: $Artifacts.total_count

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Github Workflows"
    Write-Host "---------------"

    $Workflows = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/workflows') -Method GET -Headers $headers
    
    Write-Host Number of items in the Workflows directory: $Workflows.total_count

    if ($Workflows.total_count -ne 0) {

        foreach($Workflow in $Workflows){

            Write-Host "***********"
            Write-Host Workflow Contents
            Write-Host "***********"
            $Contents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/.github/workflows') -Method GET -Headers $headers
            
            foreach($Content in $Contents) {

                Write-Host $Content.url

                $URLContent = Invoke-RestMethod ($Content.url) -Method GET -Headers $headers

                Write-Host "*******************"

                #$URLContent
                $FileContent=[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($URLContent.content))

                $on = $FileContent.indexof("on:")
                $env = $FileContent.indexof("env:")
                $diff =  $env - $on
els
                $location=$filecontent.Substring($filecontent.IndexOf("on:"), $diff)

                #Getting Triggers and Builds from Workflow files
                switch ($location)
                    {
                        {$location.contains("push:")} 					{Write-Host "Workflow is triggered by PUSH activity"}
                        {$location.contains("pull:")} 					{Write-Host "Workflow is triggered by PULL activity"}
                        {$location.contains("pull_request:")} 			{Write-Host "Workflow is triggered by PULL_REQUEST activity"}
                        {$location.contains("schedule:")} 				{Write-Host "Workflow is triggered by SCHEDULE activity"}
                        {$location.contains("release:")} 				{Write-Host "Workflow is triggered by RELEASE activity"}
                        {$location.contains("page_build:")} 			{Write-Host "Workflow is triggered by PAGE_BUILD activity"}
                        {$location.contains("workflow_dispatch:")} 		{Write-Host "Workflow is triggered manually by Workflow Dispatch"}
                        {$location.contains("repository_dispatch:")} 	{Write-Host "Workflow is triggered manually by Repository Dispatch"}
                        Default                                         {Write-Host "Workflow Trigger Method not identified or Not Present"}

                    }

                switch ($Filecontent)
                    {
                        {$FileContent.contains("docker")}               {Write-Host "Docker is used for containerization"}
                        {$FileContent.contains("jfrog")}                {Write-Host "Artifact published to Artifactory"}
                        {$FileContent.contains("Nuget")}                {Write-Host "Nuget Package present"}
                        Default                                         {Write-Host "Build not known."}
                    
                    }
                   
                if($FileContent.Contains("jfrog")) {

                    $ArtifactoryPathLocation = $FileContent.IndexOf("JFROG_CLI_REPO_NAME", "JFROG_CLI_REPO_NAME".Length)
                    Write-Host "JFROG_CLI_REPO_NAME" was found at position $ArtifactoryPathLocation
                    
                    $ArtifactoryPath = $FileContent.Substring($ArtifactoryPathLocation + "JFROG_CLI_REPO_NAME: ".Length)
                    $ArtifactoryPath = $ArtifactoryPath.Replace(":", "")
                    
                    $ArtifactoryPath = $ArtifactoryPath.Substring(0, $ArtifactoryPath.indexof("`n"))
                    

                    $ArtifactoryPath = ('https://' + $ArtifactoryLocation + '/artifactory/' + $ArtifactoryPath).Trim()
                    Write-Host Artifact is publised to Artifactory at $ArtifactoryPath
                    Write-Host 
                    "*******************" 
                                  
                }

            }
        }

        $ReposWithWorkflows++
               
    }

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Artifacts"
    Write-Host "---------------"

    $Artifacts = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/artifacts') -Method GET -Headers $headers
    Write-Host Number of Artifacts: $Artifacts.total_count

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Secrets"
    Write-Host "---------------"

    $Secrets = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/secrets') -Method GET -Headers $headers

    if($Secrets.total_count -ne 0)
    {
        for ( $index = 0; $index -lt $Secrets.total_count; $index++ ) {

        Write-Host Secret: $Secrets.secrets[$index].name   
        
        }
    }

    Write-Host Repo name is $repo.name

    Write-Host ""
    Write-Host "**************" 
        

    $RepositoryContents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents') -Method GET -Headers $headers       
        

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Branches for this repository."
    Write-Host "--------------"

    if($RepoBranches -eq $null) {
        Write-Host The repo is $repo.name
        Write-Host There are no branches for this repository.
    }
    else {
        foreach ($branch in $RepoBranches)
        {
            [int]$CountOfBranchesContainingFeature = 0

            Write-Host ""
            Write-Host "**************" 
            Write-Host The branch name is $branch.name
            Write-Host "-------------- "

            if($branch.name.Contains("feature") -or $branch.name.Contains("Feature")) {
                $CountOfBranchesContainingFeature++
            }

            Write-Host ""
            Write-Host "**************" 
            Write-Host Protection rules for this branch
            Write-Host "-------------- "
            Write-Host ""
        
            try
            {
                $ProtectionRule = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/branches/' + $branch.name + '/protection') -Method GET -Headers $headers -ErrorAction Ignore
            }
            catch
            {
                #Write-Host $_.Exception.Response
                $ProtectionRule = ""
            }
        
            if ($ProtectionRule -eq "")
            {
                Write-Host This branch is not protected.
            }
            else
            { 
                Write-Host  This branch is protected.
                Write-Host "-------------------------"

                $EnforceAdmins = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/branches/' + $branch.name + '/protection/enforce_admins') -Method GET -Headers $headers

                Write-Host Enforce admins: $EnforceAdmins.enabled

                $index = 0

                $RequiredPullRequestReviews = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/branches/' + $branch.name + '/protection/required_pull_request_reviews') -Method GET -Headers $headers
            
                Write-Host Required pull request reviews: $RequiredPullRequestReviews.required_approving_review_count
                Write-Host Dismiss stale reviews: $RequiredPullRequestReviews.dismiss_stale_reviews
                Write-Host Required status checks: $ProtectionRule.required_status_checks.checks.Count
                Write-Host Allow force pushes: $ProtectionRule.allow_force_pushes.enabled
                Write-Host Allow deletions: $ProtectionRule.allow_deletions.enabled
                Write-Host Require signatures: $ProtectionRule.required_signatures.enabled
            }

            Write-Host ""

            # TODO Group the names of the authors of all commits.
            Write-Host  Here is the latest commit information:
            Write-Host "--------------------------------------" 

            Write-Host ""       
        
            try{
                $commits = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/commits/' + $branch.name) -Method GET -Headers $headers
            }
            catch{
            }

            Write-Host $commits[0].commit.author.name
            Write-Host $commits[0].commit.author.date
            Write-Host $commits[0].commit.message
            Write-Host ""

        
            Write-Host  Total number of potention Feature branches: $CountOfBranchesContainingFeature
            Write-Host "--------------------------------------" 

            Write-Host "" 
            Write-Host "*************************************************"
            Write-Host ""
            Write-Host ""
        }

            Write-Host "*************************************************"
            Write-Host Total number of repos with workflows: $ReposWithWorkflows
         
       }   
    } 
