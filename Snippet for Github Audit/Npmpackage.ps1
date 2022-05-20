param (

    [string]$PAT = "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", # This token MUST have admin rights
    [string]$OrgName = "TBCTSystems",
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

cls

# Define clear text string for username and password
[string]$userName = 'NotNeeded'
[string]$userPassword = $PAT

# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force


#Create the credential
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Set-GitHubAuthentication -Credential $credObject -SessionOnly -ErrorAction SilentlyContinue

#####################################################################

# Access the Organizational Repo
$OrganizationalRepos = Get-GitHubRepository -OrganizationName $OrgName

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}

Write-Host There are a total of $OrganizationalRepos.Count repositories.

# Access the Organizatioal Secrets 

Write-Host ""
Write-Host "**************" 
Write-Host "Organization Secrets"
Write-Host "---------------"

$OrgSecrets = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/actions/secrets') -Method GET -Headers $headers

for ( $index = 0; $index -lt $OrgSecrets.total_count; $index++) {

    Write-Host Secret: $OrgSecrets.secrets[$index]
}

# Access the Repository and Branch Information

Write-Host ""

Write-Host "**************" 
Write-Host "Organization Repos and Branches"
Write-Host "---------------"

Write-Host ""    

$ReposWithWorkflows = 0

foreach ($repo in $OrganizationalRepos) {


    Write-Host "**************"    
    Write-Host "Repository Name:" $repo.name    

  <#Write-Host "Repository type:" $repo.visibility
    Write-Host "Repository archived:" $repo.archived
    Write-Host "Repository disabled:" $repo.disabled
    Write-Host "Repository permissions:" $repo.permissions
    Write-Host "Repository last updated " $repo.updated_at
    Write-Host Owner: $repo.owner.UserName #>


# Access Repository Languages 

    Write-Host "---------------"

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Languages"
    Write-Host "-------------- "
    $Languages = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/languages') -Method GET -Headers $headers
    $Languages | Format-Table

# Access NPM Packages for Each Repository 


      if($Languages.'JavaScript'){

        Write-Host ""
        Write-Host "**************" 
        Write-Host This repo uses JavsScript`, now reading Package Files...
        Write-Host ""

        # Search for package-lock.json files

        $packagejsonFiles = Invoke-RestMethod ('https://api.github.com/search/code?q=filename:package-lock.json+extension:json+repo:' + $OrgName + '/' + $repo.name) -Method Get -Headers $headers -ErrorAction SilentlyContinue
        

        [int]$Index = 0

        Write-Host The total count of package-lock files is $packagejsonFiles.total_count
        Write-Host ""

        foreach($packagejsonFile in $packagejsonFiles.items){

            Write-Host The name of the JS package file is $packagejsonFiles.items[$Index].name

            $PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/' + $packagejsonFiles.items[$Index].path) -Method GET -Headers $headers -ErrorAction Ignore

            $PackagelockFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($PackagelockFile.content))
            $conFile = $PackagelockFileContents | ConvertFrom-Json -ErrorAction SilentlyContinue

            $confile.dependencies.PSObject.Properties | Select-Object  Name,
            @{
                Name = 'Version'
                Expression = { $_.Value.Version }
            }, @{
                Name = 'Resolved'
                Expression = { $_.Value.Resolved }
            }
            Write-Host ""

            $Index++
            }
        
        }    

  }
