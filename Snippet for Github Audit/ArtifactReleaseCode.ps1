param (

    [string]$PAT = "",
    [string]$OrgName = ""
)

# code for promptless login:

# Clear the screen
cls

# Make sure the PowerShell gallery is trusted
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Install NuGet if necessary
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Install the Powershell module if not present
Install-Module -Name PowerShellForGitHub

# Once installed, the module must be imported to be used
Import-Module PowerShellForGitHub

# Define clear text string for username and password
[string]$userName = 'NotNeeded'  # The login requires only the PAT, but this will allow us to create a secure string
[string]$userPassword = $PAT

# Convert to SecureString
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force


# Create the credential and log in, limited to only this session
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Set-GitHubAuthentication -Credential $credObject -SessionOnly

# Access the Organizational Repos
$OrganizationalRepos = Get-GitHubRepository -OrganizationName $OrgName

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"}

Write-Host
Write-Host

#$WorkflowTest = Invoke-RestMethod ('https://api.github.com/repos/TBCTDevelopment/hwapp/actions/workflows/1184935') -Method GET -Headers $headers

#$WorkflowTest

#exit

#$Runners = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/actions/runners') -Method GET -Headers $headers
#$Runners


Write-Host There are a total of $OrganizationalRepos.Count repositories.

$Packages = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/packages?package_type=maven') -Method GET -Headers $headers
Write-Host There are $Packages.count Maven packages for this organization.

$Packages = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/packages?package_type=npm') -Method GET -Headers $headers
Write-Host There are $Packages.count NPM packages for this organization.

$Packages = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/packages?package_type=rubygems') -Method GET -Headers $headers
Write-Host There are $Packages.count Ruby Gems packages for this organization.

$Packages = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/packages?package_type=nuget') -Method GET -Headers $headers
Write-Host There are $Packages.count NuGet packages for this organization.

$Packages = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/packages?package_type=docker') -Method GET -Headers $headers
Write-Host There are $Packages.count Docker packages for this organization.

$Packages = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/packages?package_type=container') -Method GET -Headers $headers
Write-Host There are $Packages.count Container packages for this organization.

Write-Host ""
Write-Host "**************" 
Write-Host "Organization Repos and Artifacts/Releases"
Write-Host "---------------"

Write-Host ""    

# These are used for counts, initialized at 0
$index = 0
$ReposWithArtifactsCount = 0
$ReposWithReleasesCount = 0

 $Runners = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/actions/runners') -Method GET -Headers $headers

 $Runners

 

# Loop the repos
foreach ($repo in $OrganizationalRepos) {

    # Used to count the repos looped over for validation against the Github reported count
    $index++

    # Print out repo runners

    
    #$Runners = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/runners') -Method GET -Headers $headers

    #$Runners

    # Get the artifacts for the repo
    $Artifacts = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' +  $repo.name + '/actions/artifacts') -Method GET -Headers $headers

    
    # Print out if there are artifacts
    if ($Artifacts.total_count -ne 0) {

        $ReposWithArtifactsCount++
        
        Write-Host 'Repo:' $repo.name
        Write-Host '***************'
        Write-Host "Artifacts Count"
        Write-Host '***************'
        Write-Host $Artifacts.total_count
        Write-Host '***************'
        Write-Host ""
    }

    # Get releases for the repo
    $Releases = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' +  $repo.name + '/releases') -Method GET -Headers $headers

    # Print out if there are releases
    if ($Releases.Count -ne 0) {

        $ReposWithReleasesCount++    

        Write-Host 'Repo:' $repo.name
        Write-Host '***************'
        Write-Host "Releases Count"
        Write-Host '***************'
        Write-Host $Releases.Count
        Write-Host '***************'
        Write-Host ""
    }

    # Get workflows for the repo
    $Workflows = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' +  $repo.name + '/actions/workflows') -Method GET -Headers $headers

    # Print out if there are workflows
    if ($Workflows.total_count -ne 0) {

        #$ReposWithActionsCount++    

        Write-Host 'Repo:' $repo.name
        Write-Host '***************'
        Write-Host "Workflows Count"
        Write-Host '***************'
        Write-Host $Workflows.total_count
        Write-Host '***************'
        Write-Host ""

        Write-Host $Workflows[0].workflows[0]
    }

}

# Print out the descriptives

Write-Host A total of $index repositories scanned.

Write-Host Total number of repos with artifacts: $ReposWithArtifactsCount
Write-Host Total number of repos with releases: $ReposWithReleasesCount
