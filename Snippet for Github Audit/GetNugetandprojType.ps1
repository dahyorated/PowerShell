param (

    [string]$PAT = "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", # This token MUST have admin rights
    [string]$OrgName = "TBCTSystems",
    [string]$ArtifactoryLocation = "tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12
)

$ProjectType = @{
  'FAE04EC0-301F-11D3-BF4B-00C04F79EFBC' = 'CSharp'
  '349C5851-65DF-11DA-9384-00065B846F21' = 'Web_Application'
  '3D9AD99F-2412-4246-B90B-4EAA41C64699' = 'Windows_Communication_Foundation'
  '60DC8134-EBA5-43B8-BCC9-BB4BC16C2548' = 'Windows_Presentation_Foundation'
  '3AC096D0-A1C2-E12C-1390-A8335801FDAB' = 'Test'
  'A1591282-1198-4647-A2B1-27E5FF5F6F3B' = 'Silverlight'
  }

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

<# Check Repository Activeness 

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
    #>

# Access Repository Languages 

    Write-Host "---------------"

    Write-Host ""
    Write-Host "**************" 
    Write-Host "Repository Languages"
    Write-Host "-------------- "
    $Languages = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/languages') -Method GET -Headers $headers
    $Languages | Format-Table

# Access Packages for Each Repository 

  #$Files = Invoke-RestMethod ('https://api.github.com/repos/TBCTSystems/bct-common-universaldlogparser/contents/src/Bct.Common.UniversalDlogParser.Console/Bct.Common.UniversalDlogLogParser.Console.csproj') -Method Get -Headers $headers -ErrorAction SilentlyContinue
  #$Files = Invoke-RestMethod ('https://api.github.com/repos/TBCTSystems/bct-common-dlog-utils/contents/src/BCT.DlogUtils.Tests/BCT.DlogUtils.Tests.csproj') -Method Get -Headers $headers -ErrorAction SilentlyContinue
  #$FilesDecoded = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($Files.content))  
  

      #$linefile = $FilesDecoded | find.exe --% "ProjectTypeGuids" | Sort-Object -Unique
      #$linefile1 = ($linefile.trimstart('     <ProjectTypeGuids>')).trimend('</ProjectTypeGuids>')


   #$Packages1 -Like '*3AC096D0-A1C2-E12C-1390-A8335801FDAB*'
   #$Packages1 -Like '*FAE04EC0-301F-11D3-BF4B-00C04F79EFBC*'

  if($Languages.'C#'){

        Write-Host ""
        Write-Host "**************" 
        Write-Host This repo uses C#`, now reading project files...
        Write-Host ""

        # Search for csproj files

        $CSProjFiles = Invoke-RestMethod ('https://api.github.com/search/code?q=extension:csproj+repo:' + $OrgName + '/' + $repo.name) -Method Get -Headers $headers -ErrorAction SilentlyContinue
        
        #[int]$Index = 0

        #Write-Host The total count of C# project files is $CSProjFiles.total_count
        Write-Host ""

        foreach($CSProjFile in $CSProjFiles.items){

            Write-Host The name of the 'C#' project file is $CSProjFiles.items[$Index].name

            $ProjectFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/' + $CSProjFile.path <#$CSProjFiles.items[$Index].path#>) -Method GET -Headers $headers

            $ProjectFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($ProjectFile.content))

            Write-Host Packages include
            Write-Host ""

            $packages = $ProjectFileContents | Find "<PackageReference Include" | Sort-Object -Unique
            $packages1 = ($packages.trimstart('<PackageReference Include="')).trimend('"/>')
            $packages1 -replace '["]', ""

            if($ProjectFileContents.Contains("<OutputType>")){
                $diff = ($ProjectFileContents.IndexOf("</OutputType>")) - ($ProjectFileContents.IndexOf("<OutputType>"))
                $OutputType = $ProjectFileContents.Substring($ProjectFileContents.IndexOf("<OutputType>"), $diff)  
                Write-Host The project type is $look.TrimStart('<OutputType>')
              }
            
            Elseif ($ProjectFileContents.Contains("<ProjectTypeGuids>")) {
        
        
                $diff1 = ($ProjectFileContents.IndexOf("</ProjectTypeGuids")) - ($ProjectFileContents.IndexOf("<ProjectTypeGuids>"))
                $ProjTypeGuids =$ProjectFileContents.Substring($ProjectFileContents.IndexOf("<ProjectTypeGuids>"), $diff1)
                $ProjTypeGuidsTrim = $ProjTypeGuids.TrimStart('<ProjectTypeGuids>')
                $ProjTypeGuidsSplit = [Regex]::Matches($ProjTypeGuidsTrim, '(?<={)(.*?)(?=})') | Select -ExpandProperty Value
                foreach ($guid in $ProjTypeGuidsSplit) {
        
                    if($val = $ProjectType[$guid])
                {
                    "$guid => $val Project"
                    continue
                }
                "$line => could not be found on reference table."
                }

            Write-Host ""

            #$Index++
            }
        
        }   
    }
} 
