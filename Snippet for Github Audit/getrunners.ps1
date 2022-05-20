param (

    [string]$PAT = ${env:PAT}, # This token MUST have admin rights
    [string]$OrgName = ${env:OrgName},
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

# List self-hosted runners for organization

[int]$PageNumber = 1

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}

Write-Host ***************************
Write-Host Organization Self Hosted Runners
Write-Host ""

$OrgRunners = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName +  '/actions/runners') -Method GET -Headers $headers

do {

    $OrganizationalRepos = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/repos?page=' + $PageNumber + '&per_page=100') -Method GET -Headers $headers

    foreach ($repo in $OrganizationalRepos) 
    {

    Write-Host Repository Name: $repo.name
    Write-Host Repository Self Hosted Runners: 
    Write-Host ""
    
    
    $RepositoryRunners = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name +  '/actions/runners') -Method GET -Headers $headers
    
    if ($RepositoryRunners.total_count -ge 1) 
        {
            
        $RepositoryRunners | Select-Object total_count,
        @{
             Name = 'Runner ID'
             Expression = { $_.runners.id }
          },
          
        @{
             Name = 'Runner Name'
             Expression = { $_.runners.name }
         }, 
         
        @{
             Name = 'Runner OS'
             Expression = { $_.runners.os }
         },

        @{
            Name = 'Runner Status'
            Expression = { $_.runners.status }
        },
         
        @{
             Name = 'Runner Label'
             Expression = { $_.runners.labels }
         }

        }
    else {
        Write-Host No Self Hosted Runners available
            }
        
    } 
    
    
    $PageNumber++ 
    } 
until ($OrganizationalRepos.count -le 0)