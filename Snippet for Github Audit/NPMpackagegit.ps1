param (

    [string]$PAT = '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', # This token MUST have admin rights
    [string]$OrgName = "TBCTDevelopment",
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
$counter = 0

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

    Write-Host ""

    # Search for package-lock.json files

    $packagejsonFiles = Invoke-RestMethod ('https://api.github.com/search/code?q=filename:package-lock.json+extension:json+repo:' + $OrgName + '/' + $repo.name) -Method Get -Headers $headers -ErrorAction SilentlyContinue
    $counter++

    #Sleeps running program for 2 minutes to bypass 30 search API calls per minute blockage
    
    if($counter -eq 29) {Start-Sleep -s 120}
    #$packagejsonFiles = Invoke-RestMethod ('https://api.github.com/search/code?q=filename:package-lock.json+extension:json+repo:TBCTSystems/bct-svg-icon-component') -Method Get -Headers $headers -ErrorAction SilentlyContinue
    Write-Host Listing NPM packages.......................

    [int]$Index = 0
    [int]$num = 0

    Write-Host The total count of package-lock files is $packagejsonFiles.total_count
    Write-Host ""

    foreach($packagejsonFile in $packagejsonFiles.items){

        #Write-Host The name of the JS package file is $packagejsonFiles.items[$Index].name

        $PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/git/blobs/' + $packagejsonFile.sha) -Method GET -Headers $headers -ErrorAction Ignore
        #$PackagelockFile = Invoke-RestMethod ('https://api.github.com/repositories' + '/' + $packagejsonfiles.items.repository.id + '/git/blobs/' + $packagejsonFile.sha) -Method GET -Headers $headers -ErrorAction Ignore
        #$PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/' + $packagejsonFiles.items[$index].path) -Method GET -Headers $headers -ErrorAction Ignore
        #$PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/TBCTSystems/Az_Pipeline/contents/package-lock.json') -Method GET -Headers $headers -ErrorAction Ignore
        #$PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/TBCTSystems/bct-svg-icon-component/git/blobs/6576b897382d0a2e753697cb12d51ecc4e31ee3c') -Method GET -Headers $headers -ErrorAction Ignore
        $PackagelockFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($PackagelockFile.content))

        $packagejsonFilesContents = $PackagelockFileContents.Replace('" "', '""').Replace('""', "`"name`"")

        $conFile = $packagejsonFilesContents | ConvertFrom-Json -ErrorAction Ignore


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
