param (

    [string]$PAT = '', # This token MUST have admin rights
    [string]$OrgName = 'TBCTSystems',
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

# List self-hosted runners for organization
cls

[int]$PageNumber = 1
[int]$counter = 0
     $ci = @()

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}

do {
    $OrganizationalRepos = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/repos?page=' + $PageNumber + '&per_page=100') -Method GET -Headers $headers

    foreach ($repo in $OrganizationalRepos) 
    {

    Write-Host Repository Name: $repo.name
    Write-Host ""

    $RepoContents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents') -Method Get -Headers $headers -ErrorAction SilentlyContinue 

    foreach($RepoContent in $RepoContents){

    #######################################################################

    # Getting CI Folder contents in each folder 

    if($RepoContent.type.ToLower() -eq 'dir' -and $RepoContent.name.ToLower() -eq 'ci'){

    $ci = @()

    $Cicontents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/ci') -Method Get -Headers $headers -ErrorAction SilentlyContinue

    $ci+=$Cicontents
    Write-Host CI folder contents
    Write-Host ""
    $ci | Format-Table -Property name, url
    Write-Host =====================================

    }

    #######################################################################

    # Getting DB Folder contents in each folder 

    if($RepoContent.type.ToLower() -eq 'dir' -and $RepoContent.name.ToLower() -eq 'db'){

    $db = @()

    $dbcontents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/db') -Method Get -Headers $headers -ErrorAction SilentlyContinue

    $db+=$dbcontents
    Write-Host DB folder contents
    Write-Host ""
    $db | Format-Table -Property name, url
    Write-Host =====================================

    }
    

    $PageNumber++
    
    <#$GithubHostedRunners = Invoke-RestMethod ('https://api.github.com/search/code?q=EndProject:+extension:sln+repo:' + 'TBCTDevelopment' + '/' + 'Trima-Main') -Method Get -Headers $headers -ErrorAction SilentlyContinue  
    $GithubHostedRunners | Select-Object total_count, items
    $counter++ 
    #Sleep when counter up to 27
    if($counter -eq 27) {Start-Sleep -s 65} #>
        
      }
    } 
   } until ($OrganizationalRepos.count -le 0)