param (

    [string]$PAT = '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', # This token MUST have admin rights
    [string]$OrgName = "TBCTSystems",
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

cls


[int]$PageNumber = 1

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}

while($OrganizationalRepos.count -gt 0){

$OrganizationalRepos = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/repos?page=' + $PageNumber + '&per_page=100') -Method GET -Headers $headers

Write-Host $OrganizationalRepos.name

$PageNumber++}
