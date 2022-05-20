param (

    [string]$PAT = ${env:PAT}, # This token MUST have admin rights
    [string]$OrgName = ${env:OrgName},
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

# Access the Organizational Repo

[int]$PageNumber = 1

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}

do 
{

$OrganizationalRepos = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/repos?page=' + $PageNumber + '&per_page=100') -Method GET -Headers $headers

$OrganizationalRepos.name

$PageNumber++
}
until ($OrganizationalRepos.count -le 0)