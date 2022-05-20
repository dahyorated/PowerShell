# Get contents of ci folder [Done]
# pass names of ps1 files to a single array [Done]
# get contents of .gtihub/workflow and .github/actions folders 
# Pass File contents to an object/variable 
# Check if array items are contained in each workflow files and then action files. 
# if file is found in workflow/action file, output true else output false. 

param (

    [string]$PAT = '', # This token MUST have admin rights
    [string]$OrgName = 'TBCTSystems'
)


[int]$PageNumber = 1

$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"; sha = ""}


cls

do 
{

$OrganizationalRepos = Invoke-RestMethod ('https://api.github.com/orgs/' + $OrgName + '/repos?page=' + $PageNumber + '&per_page=100') -Method GET -Headers $headers

#$OrganizationalRepos.name


foreach($repo in $OrganizationalRepos){

Write-Host ""
Write-Host Repository Name: $repo.name
Write-Host ""

#Get contents of workflows files in .github/workflows folder
$Yamls = @()
$ErrorActionPreference = 'SilentlyContinue'
$WorkflowFiles = Invoke-RestMethod "https://api.github.com/repos/$($OrgName)/$($repo.name)/contents/.github/workflows" -Method Get -Headers $headers -ErrorAction SilentlyContinue

 foreach($WorkflowFile in $WorkflowFiles) {
   
   $Yamlfile = Invoke-RestMethod $WorkflowFile.url -Method Get -Headers $headers

   $Yamlfilecontents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($Yamlfile.content))

   $Yamls+=$Yamlfilecontents

    }

#Get names of PowerShell Scripts in CI folder 

$Cis = @()

$Cicontents = Invoke-RestMethod "https://api.github.com/repos/$($OrgName)/$($repo.name)/contents/ci" -Method Get -Headers $headers -ErrorAction SilentlyContinue

$cis+=$Cicontents.name

Write-Host CI folder contents
Write-Host ""

foreach($item in $cis){

    if($Yaml -match $item){

        Write-Host $item is Actively used

            } 
    else {
        Write-Host $item is not in use
    }
   
  }

 }
$PageNumber++
}
until ($OrganizationalRepos.count -le 0)