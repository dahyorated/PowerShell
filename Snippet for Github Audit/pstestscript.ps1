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
  $Files = Invoke-RestMethod ('https://api.github.com/repos/TBCTSystems/bct-common-dlog-utils/contents/src/BCT.DlogUtils.Tests/BCT.DlogUtils.Tests.csproj') -Method Get -Headers $headers -ErrorAction SilentlyContinue
  $FilesDecoded = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($Files.content))  
  


  if($FilesDecoded.Contains("<OutputType>")){
    $diff = ($FilesDecoded.IndexOf("</OutputType>")) - ($FilesDecoded.IndexOf("<OutputType>"))
    $look = $FilesDecoded.Substring($FilesDecoded.IndexOf("<OutputType>"), $diff)  
    Write-Host The project type is $look.TrimStart('<OutputType>')
  }

  Elseif ($filesDecoded.Contains("<ProjectTypeGuids>")) {

      try
      {
      $diff1 = ($FilesDecoded.IndexOf("</ProjectTypeGuids")) - ($FilesDecoded.IndexOf("<ProjectTypeGuids>"))
      $look1 =$FilesDecoded.Substring($FilesDecoded.IndexOf("<ProjectTypeGuids>"), $diff1)
      $linefile1 = $look1.TrimStart('<ProjectTypeGuids>')
      $linefile2 = [Regex]::Matches($linefile1, '(?<={)(.*?)(?=})') | Select -ExpandProperty Value
      foreach ($guid in $linefile2) {

          if($val = $ProjectType[$guid])
        {
            "$guid => $val Project"
            continue
        }
        "$line => could not be found on reference table."
      }

      #$linefile = $FilesDecoded | find.exe --% "ProjectTypeGuids" | Sort-Object -Unique
      #$linefile1 = ($linefile.trimstart('     <ProjectTypeGuids>')).trimend('</ProjectTypeGuids>')

      <#  switch ($linefile1)
            {
                {$linefile1.contains('FAE04EC0-301F-11D3-BF4B-00C04F79EFBC')} 				{Write-Host "C# Project Type Detected"}
                {$linefile1.contains('349C5851-65DF-11DA-9384-00065B846F21')} 				{Write-Host "Web Application Project Type Detected"}
                {$linefile1.contains('3D9AD99F-2412-4246-B90B-4EAA41C64699')} 			    {Write-Host "Windows Communication Foundation Project Type Detected"}
                {$linefile1.contains('60DC8134-EBA5-43B8-BCC9-BB4BC16C2548')} 				{Write-Host "Windows Presentation Foundation Project Type Detected"}
                {$linefile1.contains('3AC096D0-A1C2-E12C-1390-A8335801FDAB')} 				{Write-Host "Test Project Type Detected"}
                {$linefile1.contains('A1591282-1198-4647-A2B1-27E5FF5F6F3B')} 		        {Write-Host "Silverlight Project Type Detected"}
                Default                                                                     {Write-Host "Project Type Undetected or Unknown"}

            }
        }
        catch
        {
        Write-Host "No ProjectType entry in file"
        }
   } #>

   #$Packages1 -Like '*3AC096D0-A1C2-E12C-1390-A8335801FDAB*'
   #$Packages1 -Like '*FAE04EC0-301F-11D3-BF4B-00C04F79EFBC*'

  <#if($Languages.'C#'){

        Write-Host ""
        Write-Host "**************" 
        Write-Host This repo uses C#`, now reading project files...
        Write-Host ""

        # Search for csproj files

        $CSProjFiles = Invoke-RestMethod ('https://api.github.com/search/code?q=extension:csproj+repo:' + $OrgName + '/' + $repo.name) -Method Get -Headers $headers -ErrorAction SilentlyContinue
        
        [int]$Index = 0

        Write-Host The total count of C# project files is $CSProjFiles.total_count
        Write-Host ""

        foreach($CSProjFile in $CSProjFiles.items){

            Write-Host The name of the C# project file is $CSProjFiles.items[$Index].name

            $ProjectFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/' + $CSProjFiles.items[$Index].path) -Method GET -Headers $headers

            $ProjectFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($ProjectFile.content))

            Write-Host Packages include
            Write-Host ""

            $packages = $ProjectFileContents | Find "<PackageReference Include" | Sort-Object -Unique
            $packages1 = ($packages.trimstart('<PackageReference Include="')).trimend('"/>')
            $packages1 -replace '["]', ""

            Write-Host ""

            $Index++
            }
        
        }   

       <# #$Files = Invoke-RestMethod ('https://api.github.com/repos/TBCTSystems/actions-bump-version/contents/package-lock.json') -Method Get -Headers $headers -ErrorAction SilentlyContinue
        $FilesDecoded = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($Files.content))
        #$FilesDecoded | ConvertFrom-Json | Select-Object -ExpandProperty Dependencies 
        $conFile = $FilesDecoded | ConvertFrom-Json
        

      <# $confile.dependencies.PSObject.Properties | Select-Object  Name,
            @{
                Name = 'Version'
                Expression = { $_.Value.Version }
            }, @{
                Name = 'Resolved'
                Expression = { $_.Value.Resolved }
            } #>


            Write-Host ""

            $num++
            $Index++
            }
        
           

  




<#
$extract = $ProjectFileContents | find.exe --% "<GenerateDocumentationFile>" | Sort-Object -Unique
$extract1 = ($extract.trimstart('<GenerateDocumentationFile>')).trimend('</GenerateDocumentationFile>')
$extract1 -replace '["]', "" #>