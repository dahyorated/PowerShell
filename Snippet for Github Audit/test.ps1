param (

    [string]$PAT = "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", # This token MUST have admin rights
    [string]$OrgName="TBCTDevelopment",
    [string]$ArtifactoryLocation="tbctdevops.jfrog.io",
    [int]$MonthsToDeclareInactiveRepo = 12,
    [boolean]$WriteToSQL = $false,
    [string]$SqlServer="",
    [string]$Database="",
    [string]$DBUser,
    [string]$DBPassword
)

#TODO: Mark branches as "inactive" based on same calculations for repos
# Note number of issues
# Provide language breakdown of each repository
# Provide type of build: container, etc.
# Maybe the license type??
# code for promptless login:

# Obtain info for only a specific repo, and then possibly by branch name
function BoolToBit{

    param(
        [boolean]$bool
    )

    if($bool -eq $true){
        return [int]1
    }
    else{
        return [int]0
    }
}

#Create a hashtable which contains possible workflow name
# = @(("Release", "Release" ), ("Build", "Build"), ("Test", "Test"), ("CI/CD", "Continuous Integration"))

$WorkflowTypes=@{"Name" = @("release", "build", "test", "ci/cd")
    "Type" = @("Release Workflow", "Build Workflow", "Testing Workflow", "CI/CD Workflow")
}

#$key = "CI/CD"
#$key = $key.ToLower()

#if($ht.Name.Contains($key)){
#    Write-Host $WorkflowTypes['Type'][$WorkflowTypes['Name'].IndexOf($key)] 
#}

cls

<#
try{
    Register-PSRepository -Name Default -InstallationPolicy Trusted -SourceLocation https://www.powershellgallery.com/api/v2/ -ErrorAction SilentlyContinue
}
catch{
    Write-Host Unable to register the PSGallery repository.
}    

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -ErrorAction SilentlyContinue

# Install/import the modules if not present
Install-Module -Name SqlServer -AllowClobber -Repository Default

Import-Module SqlServer 
#>

#This will track the number of API calls we make to the general API
[int]$APIGeneralCallsCount=0

#This will track the number of API calls we make to the search API
[int]$APISearchCallsCount=0

#This will track the number of API calls we make to the data API
[int]$APIDataCallsCount=0


$WorkflowNamesList = @()
[int]$WorkflowsCount = 0

if($WriteToSQL){  # Set up the SQL connection if needed

    # Flag database storage or not
    $SQLConnectionString = "Server='$SqlServer';Database='$Database';User ID='$DBUser';Password='$DBPassword'"
    
    $SQLConnection = New-Object System.Data.SqlClient.SqlConnection $SQLConnectionString

    try{

        $SQLConnection.Open()   
 
        if($SQLConnection.State -eq "Open"){
        
            Write-Host "************************************"
            Write-Host "Database connection test successful!"
            Write-Host "------------------------------------"
            Write-Host

            # Dispose in case of an error further down.
            $SQLConnection.Dispose()
        }
        else
        {
            Write-Host Unable to connect to SQL server.  Verify that the username, password, database name, and server name/instance are correct.
        
            return(-1)
        }
    }
    catch{

            Write-Host Unable to connect to SQL server.  Verify that the username, password, database name, and server name/instance are correct.

        try{

            Write-Host Closing the connection

            $SQLConnection.Dispose()

        }
        catch{
        }
        finally{

            exit

        }
    }
}  #End setting up SQL connection string if needed

# Store the organization name
if($WriteToSQL){  #Begin writing organization name to DB

    $SQLConnection.ConnectionString=$SQLConnectionString
    $SQLConnection.Open()

    $SqlCmd.Dispose()
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = "proc_InsertOrganization"
    $SqlCmd.Connection = $SqlConnection
    $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

    $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
    $param1.Value=$OrgName

    $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
    $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue

    $result = $SqlCmd.ExecuteNonQuery()

    $OrganizationID = [string]$sqlCmd.Parameters["@ReturnValue"].Value
            
    $SQLConnection.Close()
    
}  #End writing organization name to DB

Write-Host "Organization:  $OrgName"
Write-Host

# Build the header elements needed for the API calls
$headers = @{ Accept = "application/vnd.github.v3+json"; Authorization = "token $PAT"} #; sha = ""}

# Set up external counters
$PageNumber = 1
$RepoCount=0
$OrganizationalRepos=@()
$Languages=@()

#Obtain the full list of repositories and account for pagination
while($true){ 

    $OrganizationalReposAPICall = Invoke-RestMethod "https://api.github.com/orgs/$OrgName/repos?sort=full_name&per_page=100&page=$PageNumber" -Method GET -Headers $headers   

    if($OrganizationalReposAPICall.Count -le 0)
    {
        # If the page is empty, exit the loop      
        break
    }

    #Increase the repository count
    $RepoCount=$RepoCount+$OrganizationalReposAPICall.count    

    foreach($Repo in $OrganizationalReposAPICall){
       
        #Print out the repository name
        Write-Host Repo name is $repo.name
        $OrganizationalRepos+=$Repo
        Write-Host

    }
    
    #Increment the page number for our next call
    $PageNumber++

    #Increment the API call counter
    $APIGeneralCallsCount++

}

Write-Host There are a total of $RepoCount repositories.

Write-Host

Write-Host "********************" 
Write-Host "Organization Secrets"
Write-Host "--------------------"
Write-Host

$PageNumber=1
$Index = 0

while($true){

    $OrgSecrets = Invoke-RestMethod "https://api.github.com/orgs/$OrgName/actions/secrets?per_page=100&page=$PageNumber" -Method GET -Headers $headers

    #Increment the counter
    $APIGeneralCallsCount++

    if($OrgSecrets.secrets.Count -le 0){ #Check if there are any secrets returned
        # If the page is empty, reduce the page count to remove this page and then break the loop
        break
    } #End count check

    #For each secret found, write the name, visibility, and the secret
    for($index = 0;$index -lt $OrgSecrets.secrets.Count;$index++){  #Begin looping through the organizational secrets

        #Write out the secrets.  TODO: They come as an array so this needs some parsing.
        Write-Host Secret name: $OrgSecrets.secrets[$index].name
        Write-Host Secret visibility: $OrgSecrets.secrets[$index].visibility
        Write-Host Secret created: $OrgSecrets.secrets[$index].created_at
        Write-Host Secret updated: $OrgSecrets.secrets[$index].updated_at

        if($WriteToSQL){  #Begin writing secrets to DB
        
            $SQLConnection.ConnectionString=$SQLConnectionString
            $SQLConnection.Open()

            $SqlCmd.Dispose()
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = "proc_InsertOrganizationSecret"
            $SqlCmd.Connection = $SqlConnection
            $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

            $param1=$sqlcmd.Parameters.Add("@OrganizationId", [System.Data.SqlDbType]::Int)
            $param1.Value=$OrganizationID

            $param1=$sqlcmd.Parameters.Add("@SecretName", [System.Data.SqlDbType]::Int)
            $param1.Value=$OrgSecrets.secrets[$index].name

            $param1=$sqlcmd.Parameters.Add("@Created", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$OrgSecrets.secrets[$index].created_at
        
            $param1=$sqlcmd.Parameters.Add("@LastUpdated", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$OrgSecrets.secrets[$index].updated_at

            $param1=$sqlcmd.Parameters.Add("@Visibility", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$OrgSecrets.secrets[$index].visibility
        
            $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
            $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue

            $result = $SqlCmd.ExecuteNonQuery()

            $returnValue = [int]$sqlCmd.Parameters["@ReturnValue"].Value

            $SQLConnection.Dispose()
        
        }  #End writing secrets to DB
        
        Write-Host
    }        

    $PageNumber++

} #End looping through the organizational secrets


Write-Host 
Write-Host "*******************************" 
Write-Host "Organization Repos and Branches"
Write-Host "-------------------------------"
Write-Host

#Begin looping through each repository and gather information

foreach($repo in $OrganizationalRepos){  #Begin the repository data gathering loop    

    #Output the basic repository properties
    Write-Host
    Write-Host "********************************************"         
    Write-Host "Repository Status"
    Write-Host "--------------------------------------------"
    Write-Host "Repository Name:" $repo.name
    Write-Host "Repository visibility:" $repo.visibility
    Write-Host "Repository archived:" $repo.archived
    Write-Host "Repository disabled:" $repo.disabled
    Write-Host "Repository permissions:" $repo.permissions    
    Write-Host "Repository last updated: " $repo.updated_at
    Write-Host Owner: $repo.owner.UserName

    #Determine if the repository is stale based upon the last update date and the number of months
    #provided to the script to determine if it is stale

    $UpdatedAt = [datetime]$repo.updated_at
    $CurrentDate = Get-Date
    $PreviousDate = $CurrentDate.AddMonths(-$MonthsToDeclareInactiveRepo)

    if ($UpdatedAt -gt $PreviousDate)
    {
        Write-Host "Repo is active."
        $RepoIsActive=$true
    }
    else
    {
        Write-Host "Repo is inactive."
        $RepoIsActive=$false
    }
    
    Write-Host "--------------------------------------------" 

    if($WriteToSQL){  #Begin writing repository properties to DB

        $SQLConnection.ConnectionString=$SQLConnectionString
        $SQLConnection.Open()

        $SqlCmd.Dispose()
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = "proc_InsertRepository"
        $SqlCmd.Connection = $SqlConnection
        $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

        $param1=$sqlcmd.Parameters.Add("@OrganizationId", [System.Data.SqlDbType]::Int)
        $param1.Value=$OrganizationID

        $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.name

        $param1=$sqlcmd.Parameters.Add("@Visibility", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.visibility

        $param1=$sqlcmd.Parameters.Add("@Archived", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.archived.ToString()
        
        $param1=$sqlcmd.Parameters.Add("@Disabled", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.disabled.ToString()
        
        $param1=$sqlcmd.Parameters.Add("@LastUpdated", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.updated_at.ToString()
        
        $param1=$sqlcmd.Parameters.Add("@Active", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$RepoIsActive.ToString()
        
        $param1=$sqlcmd.Parameters.Add("@Owner", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.owner.UserName

        $param1=$sqlcmd.Parameters.Add("@Admin", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.permissions.admin

        $param1=$sqlcmd.Parameters.Add("@Maintain", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.permissions.maintain

        $param1=$sqlcmd.Parameters.Add("@Push", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.permissions.push

        $param1=$sqlcmd.Parameters.Add("@Triage", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.permissions.triage

        $param1=$sqlcmd.Parameters.Add("@Pull", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$repo.permissions.pull

        $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
        $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
        $result = $SqlCmd.ExecuteNonQuery()

        $RepositoryId = $sqlCmd.Parameters["@ReturnValue"].Value

        $SQLConnection.Close()
                
    }  #End writing repository properties to DB

    #Gather the languages used by the repository, if GitHub can return them
    Write-Host 
    Write-Host "************************" 
    Write-Host "Repository Languages"
    Write-Host "------------------------"

    $Languages = Invoke-RestMethod "https://api.github.com/repos/$OrgName/$($repo.name)/languages" -Method GET -Headers $headers

    #Increment the counter
    $APIGeneralCallsCount++

    #If GitHub doesn't return known languages, output the message and continue
    Write-Host "**********************************"
    Write-Host Languages found in this repository
    Write-Host "----------------------------------"
    Write-Host

    $Languages | Format-Table        
    
    if($null -eq $Languages){
        Write-Host No languages identified.
    }
    else{

        foreach($Language in $Languages){ #Start moving through the array
            
            if($Language.'C#'){

                Write-Host
                Write-Host "************************************************" 
                Write-Host This repo uses C`#, now reading project files...
                Write-Host "------------------------------------------------"
                Write-Host
               
                if($WriteToSQL){ #Write to the database

                $SQLConnection.ConnectionString=$SQLConnectionString
                $SQLConnection.Open()

                $SqlCmd.Dispose()
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $SqlCmd.CommandText = "proc_InsertRepositoryLanguage"
                $SqlCmd.Connection = $SqlConnection
                $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                $param1=$sqlcmd.Parameters.Add("@RepositoryId", [System.Data.SqlDbType]::Int)
                $param1.Value=$RepositoryId

                $param1=$sqlcmd.Parameters.Add("@Language", [System.Data.SqlDbType]::NVarChar)
                $param1.Value="C#"

                $param1=$sqlcmd.Parameters.Add("@Size", [System.Data.SqlDbType]::Int)
                $param1.Value=0 #TODO: Where is the size property?

                $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
    
                $result = $SqlCmd.ExecuteNonQuery()

                $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                $SQLConnection.Close()
                                
                } #End write to the database             

                # Search for csproj files
                Write-Host Searching for CSPROJ files            

                $CSProjFiles = Invoke-RestMethod "https://api.github.com/search/code?q=extension:csproj+repo:$($OrgName)/$($repo.name)" -Method Get -Headers $headers
                #$CSProjFiles
                Write-Host
                Write-Host The total count of C`# project files is $CSProjFiles.total_count
                Write-Host

                foreach($CSProjFile in $CSProjFiles.items){ #Begin looping through the project files

                    Write-Host The name of the C`# project file is $CSProjFiles.items[$Index].name
                    
                    if($WriteToSQL){ #Write to database

                        $SQLConnection.ConnectionString=$SQLConnectionString
                        $SQLConnection.Open()

                        $SqlCmd.Dispose()
                        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                        $SqlCmd.CommandText = "proc_InsertProjectFile"
                        $SqlCmd.Connection = $SqlConnection
                        $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                        $param1=$sqlcmd.Parameters.Add("@RepositoryId", [System.Data.SqlDbType]::Int)
                        $param1.Value=$RepositoryId

                        $param1=$sqlcmd.Parameters.Add("@Filename", [System.Data.SqlDbType]::NVarChar)
                        $param1.Value=$CSProjFiles.items[$Index].name

                        $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                        $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
    
                        $result = $SqlCmd.ExecuteNonQuery()

                        $ProjectFileId = $sqlCmd.Parameters["@ReturnValue"].Value

                        $SQLConnection.Close()
            
                    } #End writing to database

                    #Get the contents of the file
                    $ProjectFile = Invoke-RestMethod ("https://api.github.com/repos/$($OrgName)/$($repo.name)/contents/" + $CSProjFiles.items[$Index].path) -Method GET -Headers $headers
                    $APIGeneralCallsCount++
                   
                    #Decode the contents from base64
                    $ProjectFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($ProjectFile.content))

                    #Eliminate the beginning characters so that the contents are JSON
                    $ProjectFileContents = @($ProjectFileContents.Substring(3))

                    #Obtain the list of package references
                    $PackageReferences = $ProjectFileContents | Find "<PackageReference Include" | Sort-Object -Unique
                        
                    if($PackageReferences -eq ""){ #Begin if no package references were found
                        Write-Host No package references were found.
                    } #End if no package references were found
                    else{ #Beging listing the package references
                        Write-Host Package references were found.
                        Write-Host
                        #Print out each package reference
                        foreach($PackageReference in $PackageReferences){ #Begin write package references

                            $ReferenceRow = $PackageReference.Substring($PackageReference.IndexOf("Include=")+9)
                            $ReferenceRow = $ReferenceRow.replace("/>", "")
                            $ReferenceRow = $ReferenceRow.replace("`"", "")
                            $ReferenceRow = $ReferenceRow.replace(">","")

                            Write-Host Package Reference:  $ReferenceRow

                            if($WriteToSQL){ #Write to database

                                $SQLConnection.ConnectionString=$SQLConnectionString
                                $SQLConnection.Open()

                                $SqlCmd.Dispose()
                                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                                $SqlCmd.CommandText = "proc_InsertPackageReference"
                                $SqlCmd.Connection = $SqlConnection
                                $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                                $param1=$sqlcmd.Parameters.Add("@ProjectFileId", [System.Data.SqlDbType]::Int)
                                $param1.Value=$ProjectFileId

                                $param1=$sqlcmd.Parameters.Add("@PackageReference", [System.Data.SqlDbType]::NVarChar)
                                $param1.Value=$ReferenceRow.ToString()

                                $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                                $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
    
                                $result = $SqlCmd.ExecuteNonQuery()

                                $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                                $SQLConnection.Close()

                            } #End of write to database
                    
                        } #End else/roeach statement for finding of package references

                        #Check for assembly references            
                        $References = $ProjectFileContents | Find "<Reference Include=" | Sort-Object -Unique

                        if($References -eq ""){ #Begin if no references were found
                            Write-Host No references were found.
                        } #End if no references were found
                        else{ #Begin if package references were found

                            Write-host References were found
                            Write-Host

                            #Write out each reference
                            foreach($Reference in $References){ #Begin writing references

                                $ReferenceRow = $Reference.Substring($Reference.IndexOf("Include=")+9)
                                $ReferenceRow = $ReferenceRow.replace("/>", "")
                                $ReferenceRow = $ReferenceRow.replace("`"", "")
                                $ReferenceRow = $ReferenceRow.replace(">","")

                                Write-Host Reference:  $ReferenceRow

                                if($WriteToSQL){ #Write to database

                                    $SQLConnection.ConnectionString=$SQLConnectionString
                                    $SQLConnection.Open()

                                    $SqlCmd.Dispose()
                                    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                                    $SqlCmd.CommandText = "proc_InsertReference"
                                    $SqlCmd.Connection = $SqlConnection
                                    $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                                    $param1=$sqlcmd.Parameters.Add("@ProjectFileId", [System.Data.SqlDbType]::Int)
                                    $param1.Value=$ProjectFileId

                                    $param1=$sqlcmd.Parameters.Add("@Reference", [System.Data.SqlDbType]::NVarChar)
                                    $param1.Value=$ReferenceRow

                                    $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                                    $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                                    $result = $SqlCmd.ExecuteNonQuery()

                                    $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                                    $SQLConnection.Close()

                                }#End write to database
                        
                            }#End writing references
                            Write-Host End of packages
                            
                        }#End of else for references
                    }

                }
            } #End of c# loop
            
            #Look for NPM packages
            $packagejsonFiles = Invoke-RestMethod ('https://api.github.com/search/code?q=filename:package-lock.json+extension:json+repo:' + $OrgName + '/' + $repo.name) -Method Get -Headers $headers -ErrorAction SilentlyContinue            
    
            Write-Host Listing NPM packages.......................
            
            Write-Host The total count of package-lock files is $packagejsonFiles.total_count
            Write-Host ""
            $Index=0
            Write-Host Repo is $repo.name

        ############################################################
            do { 

                Write-Host
                Write-Host "********************************************************"
                Write-Host The name of the JS package file is $packagejsonFile.url
                Write-Host "--------------------------------------------------------"
                Write-Host

            $PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/git/blobs/' + $packagejsonFiles.items[$index].sha) -Method GET -Headers $headers

                $PackagelockFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($PackagelockFile.content))

                $packagejsonFilesContents = $PackagelockFileContents.Replace('" "', '""').Replace('""', "`"name`"")

                #$packagejsonFilesContents

                $conFile = $packagejsonFilesContents | ConvertFrom-Json -ErrorAction Ignore 
                $conFile

               <# $NPMpackages = ($confile.dependencies.PSObject.Properties | Select-Object  Name,
                @{
                    Name = 'Version'
                    Expression = { $_.Value.Version }
                }, @{
                    Name = 'Resolved'
                    Expression = { $_.Value.Resolved }
                })

                $NPMpackages #>

                Write-Host ""
                $Index++

                # End foreach on the NPM files
            
            if($packagejsonFiles.total_count -ne 0){
              
            } }
                
            until ($Index -eq $packagejsonFiles.total_count)

           exit

           #######################################################

           <# foreach($packagejsonFile in $packagejsonFiles.items){ #Start foreach on NPM files

                Write-Host
                Write-Host "********************************************************"
                Write-Host The name of the JS package file is $packagejsonFile.url
                Write-Host "--------------------------------------------------------"
                Write-Host

                $PackagelockFile = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/git/blobs/' + $packagejsonFiles.items[$index].sha) -Method GET -Headers $headers

                #$PackagelockFile = Invoke-RestMethod ($packagejsonFile.url) -Method GET -Headers $headers
                
                #$PackagelockFile = Invoke-RestMethod "https://api.github.com/repos/$($OrgName)/$($repo.name)/git/blobs/$($packagejsonFile.sha))" -Method GET -Headers $headers
                
                $PackagelockFileContents = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($PackagelockFile.content))

                $packagejsonFilesContents = $PackagelockFileContents.Replace('" "', '""').Replace('""', "`"name`"")

                $conFile = $packagejsonFilesContents | ConvertFrom-Json -ErrorAction Ignore

                $NPMpackages = ($confile.dependencies.PSObject.Properties | Select-Object  Name,
                @{
                    Name = 'Version'
                    Expression = { $_.Value.Version }
                }, @{
                    Name = 'Resolved'
                    Expression = { $_.Value.Resolved }
                })

                $NPMpackages

                Write-Host ""
                $Index++
                
            } # End foreach on the NPM files
            
            if($packagejsonFiles.total_count -ne 0){
                exit
            }#>
        }
    }
}           Write-Host "-------------- "
            Write-Host          

    Write-Host
    #Getting Contributors on Each Repository
    Write-Host "**************" 
    Write-Host "Repository Contributors"
    Write-Host "-------------- "

    $Contributors = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contributors') -Method GET -Headers $headers
    
    foreach($Contributor in $Contributors){

        if($WriteToSQL)
        {

            $SQLConnection.ConnectionString=$SQLConnectionString
            $SQLConnection.Open()

            $SqlCmd.Dispose()
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = "proc_InsertContributor"
            $SqlCmd.Connection = $SqlConnection
            $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

            $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::Int)
            $param1.Value=$RepositoryId

            $param1=$sqlcmd.Parameters.Add("@login", [System.Data.SqlDbType]::NVarChar)
            $param1.Value= if ($Contributor.login -eq $null) { "" } else { $Contributor.login }

            $param1=$sqlcmd.Parameters.Add("@site_admin", [System.Data.SqlDbType]::NChar)
            $param1.Value= if ($Contributor.site_admin -eq $null) { "" } else { $Contributor.site_admin }

            $param1=$sqlcmd.Parameters.Add("@contributions", [System.Data.SqlDbType]::NVarChar)
            $param1.Value= if ($Contributor.contributions -eq $null) { 0 } else { $Contributor.contributions }

            $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
            $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
            $result = $SqlCmd.ExecuteNonQuery()

            $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

            $SQLConnection.Close()

        }
    }
        
    $Contributors
    
    Write-Host

    #Getting Teams attached to each Repository
    Write-Host "**************" 
    Write-Host "Repository Teams"
    Write-Host "---------------"
    $repoteams = Get-GitHubTeam -OwnerName $OrgName -RepositoryName $repo.name
    $repoteams

    foreach($RepoTeam in $RepoTeams)
    {
        if($WriteToSQL)
        {

            $SQLConnection.ConnectionString=$SQLConnectionString
            $SQLConnection.Open()

            $SqlCmd.Dispose()
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = "proc_InsertTeam"
            $SqlCmd.Connection = $SqlConnection
            $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

            $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
            $param1.Value=$RepositoryId

            $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$RepoTeam.name

            $param1=$sqlcmd.Parameters.Add("@Slug", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$RepoTeam.slug

            $param1=$sqlcmd.Parameters.Add("@Privacy", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$RepoTeam.privacy

            $param1=$sqlcmd.Parameters.Add("@Permission", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$RepoTeam.permission

            $param1=$sqlcmd.Parameters.Add("@Admin", [System.Data.SqlDbType]::NChar)
            $param1.Value=$RepoTeam.permissions.admin

            $param1=$sqlcmd.Parameters.Add("@Maintain", [System.Data.SqlDbType]::NChar)
            $param1.Value=$RepoTeam.permissions.maintain

            $param1=$sqlcmd.Parameters.Add("@Push", [System.Data.SqlDbType]::NChar)
            $param1.Value=$RepoTeam.permissions.push

            $param1=$sqlcmd.Parameters.Add("@Triage", [System.Data.SqlDbType]::NChar)
            $param1.Value=$RepoTeam.permissions.triage

            $param1=$sqlcmd.Parameters.Add("@Pull", [System.Data.SqlDbType]::NChar)
            $param1.Value=$RepoTeam.permissions.pull
            
            $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
            $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
            $result = $SqlCmd.ExecuteNonQuery()

            $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

            $SQLConnection.Close()
                
        }
    }

    Write-Host "---------------"    

    Write-Host
    Write-Host "***************" 
    Write-Host "Repository Tags"
    Write-Host "---------------"

    $RepoTags = Get-GitHubRepositoryTag -OwnerName $OrgName -RepositoryName $repo.name

    
    $RepoTags | Format-Table

    foreach($RepoTag in $RepoTags)
    {
       
        if($WriteToSQL)
        {

            $SQLConnection.ConnectionString=$SQLConnectionString
            $SQLConnection.Open()

            $SqlCmd.Dispose()
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = "proc_InsertTag"
            $SqlCmd.Connection = $SqlConnection
            $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

            $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
            $param1.Value=$RepositoryId

            $param1=$sqlcmd.Parameters.Add("@Tag", [System.Data.SqlDbType]::NVarChar)
            $param1.Value=$RepoTag.name
            
            $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
            $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
            $result = $SqlCmd.ExecuteNonQuery()

            $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

            $SQLConnection.Close()
                
        }        
    }

    #Get the branches for this repository
    $RepoBranches = Get-GitHubRepositoryBranch -OwnerName $OrgName -RepositoryName $repo.name

   
    $Artifacts = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/artifacts') -Method GET -Headers $headers
    Write-Host Number of Artifacts: $Artifacts.total_count

    Write-Host
    Write-Host "****************" 
    Write-Host "Github Workflows"
    Write-Host "----------------"

    #Get the workflows for this repository
    $Workflows = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/workflows') -Method GET -Headers $headers
    
    #Output the number of workflows found
    Write-Host Number of items in the Workflows directory: $Workflows.total_count

    if($Workflows.total_count -ne 0){

        $WorkflowsCount+=$Workflows.total_count

        foreach($Workflow in $Workflows){
            
            Write-Host "****************"
            Write-Host Workflow Contents
            Write-Host "----------------"

            #Get the contents of the /.github/workflows folder as each workflow has a corresponding YAML file
            $Contents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents/.github/workflows') -Method GET -Headers $headers            
            
            foreach($Content in $Contents) {

                if($WriteToSQL)
                {

                    $SQLConnection.ConnectionString=$SQLConnectionString
                    $SQLConnection.Open()

                    $SqlCmd.Dispose()
                    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                    $SqlCmd.CommandText = "proc_InsertWorkflow"
                    $SqlCmd.Connection = $SqlConnection
                    $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                    $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
                    $param1.Value=$RepositoryId

                    $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
                    $param1.Value=$Content.name
            
                    $param1=$sqlcmd.Parameters.Add("@URL", [System.Data.SqlDbType]::NVarChar)
                    $param1.Value=$Content.url
                    
                    $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                    $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                    $result = $SqlCmd.ExecuteNonQuery()

                    $WorkflowId = $sqlCmd.Parameters["@ReturnValue"].Value

                    $SQLConnection.Close()
                
                }   
                     
                Write-Host Workflow filename: $Content.name
                Write-Host Workflow URL:  $Content.url
                
                $URLContent = Invoke-RestMethod ($Content.url) -Method GET -Headers $headers

                Write-Host "*******************"

                #$URLContent
                $FileContent=[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($URLContent.content))

                if($FileContent.Contains("name:")){
                    Write-Host Name was found at , $FileContent.IndexOf("name:")

                    #Find where "name:" exists in the file
                    $NameStart = $FileContent.IndexOf("name:")
                    Write-Host Namestart is $NameStart

                    #Find where the first line break after "name:" was found
                    Write-Host The end of the line was found at $FileContent.IndexOf("`n", $NameStart)

                    #Calculate the end of the line and get the substring from "name:" to the end of the line
                    $EndOfLine=$FileContent.IndexOf("`n", $NameStart)
                    $WorkflowNameFromFile = $filecontent.Substring($NameStart, $EndOfLine)
                   
                    #Now clean up the line
                    $WorkflowNameFromFile = $TheLine.trim()

                    #TEMP: Add to the names array so that we can get a list of what we find
                    Write-Host The entire line is $WorkflowNameFromFile                    
                    $WorkflowNamesList += ($WorkflowNameFromFile)

                }
                else{
                    Write-Host Name was NOT found
                    $WorkFlowNamesList += A name entry was not found in repo $repo.name, file $Content.name
                }

                #Finding the
                $on = $FileContent.indexof("on:")
                $env = $FileContent.indexof("env:")
                $diff =  $env - $on

                if($env -lt 0){
                    $diff=$on                    
                }

                $location=$filecontent.Substring($filecontent.IndexOf("on:"), $diff)
               
                # Initially set the flags
                $push=$false
                $pull=$false
                $pullrequest=$false
                $schedule=$false
                $release=$false
                $pagebuild=$false
                $workflowdispatch=$false
                $repositorydispatch=$false
                $unknown=$false
                $DockerFound=$false
                $ArtifactoryFound=$false
                $NugetFound=$false
                $ArtifactoryPath=""

                #Getting Triggers and Builds from Workflow files
                
                switch ($FileContent)
                {
                    {$FileContent.contains("push")} 					{Write-Host "Workflow is triggered by PUSH activity"; $push=$true}
                    {$FileContent.contains("pull")} 					{Write-Host "Workflow is triggered by PULL activity"; $pull=$true}
                    {$FileContent.contains("pull_request")} 			{Write-Host "Workflow is triggered by PULL_REQUEST activity"; $pullrequest=$true}
                    {$FileContent.contains("schedule")} 				{Write-Host "Workflow is triggered by SCHEDULE activity"; $schedule=$true}
                    {$FileContent.contains("release")} 				    {Write-Host "Workflow is triggered by RELEASE activity"; $release=$true}
                    {$FileContent.contains("page_build")} 			    {Write-Host "Workflow is triggered by PAGE_BUILD activity"; $pagebuild=$true}
                    {$FileContent.contains("workflow_dispatch")} 		{Write-Host "Workflow is triggered manually by Workflow Dispatch"; $workflowdispatch=$true}
                    {$FileContent.contains("repository_dispatch")} 	    {Write-Host "Workflow is triggered manually by Repository Dispatch"; $repositorydispatch=$true}
                    Default                                             {Write-Host "Workflow Trigger Method not identified or Not Present"; $unknown=$true}
                }                
                
                if($WriteToSQL)
                {

                    $SQLConnection.ConnectionString=$SQLConnectionString
                    $SQLConnection.Open()

                    $SqlCmd.Dispose()
                    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                    $SqlCmd.CommandText = "proc_InsertWorkflowTriggers"
                    $SqlCmd.Connection = $SqlConnection
                    $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                    $param1=$sqlcmd.Parameters.Add("@WorkflowId", [System.Data.SqlDbType]::int)
                    $param1.Value=$WorkflowId

                    $param1=$sqlcmd.Parameters.Add("@Push", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$push.tostring()
                    
                    $param1=$sqlcmd.Parameters.Add("@Pull", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$pull.tostring()

                    $param1=$sqlcmd.Parameters.Add("@PullRequest", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$pullrequest.tostring()

                    $param1=$sqlcmd.Parameters.Add("@schedule", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$schedule.tostring()

                    $param1=$sqlcmd.Parameters.Add("@release", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$release.tostring()

                    $param1=$sqlcmd.Parameters.Add("@pagebuild", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$pagebuild.tostring()
                    
                    $param1=$sqlcmd.Parameters.Add("@workflowdispatch", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$workflowdispatch.tostring()

                    $param1=$sqlcmd.Parameters.Add("@repositorydispatch", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$repositorydispatch.tostring()

                    $param1=$sqlcmd.Parameters.Add("@unknown", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$unknown.tostring()

                    $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                    $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                    $result = $SqlCmd.ExecuteNonQuery()

                    $WorkflowTriggersId = $sqlCmd.Parameters["@ReturnValue"].Value

                    $SQLConnection.Close()
                
                }
                
                switch ($Filecontent)
                {
                    {$FileContent.contains("docker")}               {Write-Host "Docker is used for containerization"; $DockerFound=$true}
                    {$FileContent.contains("jfrog")}                {Write-Host "Artifact published to Artifactory"; $ArtifactoryFound=$true}
                    {$FileContent.contains("Nuget")}                {Write-Host "Nuget Package present"; $NugetFound=$true}
                    Default                                         {Write-Host "Build not known."}
                    
                }
                
                # Reset the flags
                $push=$false
                $pull=$false
                $pullrequest=$false
                $schedule=$false
                $release=$false
                $pagebuild=$false
                $workflowdispatch=$false
                $repositorydispatch=$false
                $unknown=$false
                $DockerFound=$false
                $ArtifactoryFound=$false
                $NugetFound=$false
                $ArtifactoryPath=""
   
                if($FileContent.Contains("jfrog")) {

                    $ArtifactoryPathLocation = $FileContent.IndexOf("JFROG_CLI_REPO_NAME", "JFROG_CLI_REPO_NAME".Length)
                    Write-Host "JFROG_CLI_REPO_NAME" was found at position $ArtifactoryPathLocation
                    
                    $ArtifactoryPath = $FileContent.Substring($ArtifactoryPathLocation + "JFROG_CLI_REPO_NAME: ".Length)
                    $ArtifactoryPath = $ArtifactoryPath.Replace(":", "")
                    
                    $ArtifactoryPath = $ArtifactoryPath.Substring(0, $ArtifactoryPath.indexof("`n"))
                    

                    $ArtifactoryPath = ('https://' + $ArtifactoryLocation + '/artifactory/' + $ArtifactoryPath).Trim()
                    Write-Host Artifact is publised to Artifactory at $ArtifactoryPath
                    Write-Host 
                    "*******************" 

                }

                if($WriteToSQL)
                {

                    $SQLConnection.ConnectionString=$SQLConnectionString
                    $SQLConnection.Open()

                    $SqlCmd.Dispose()
                    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                    $SqlCmd.CommandText = "proc_InsertWorkflowProperties"
                    $SqlCmd.Connection = $SqlConnection
                    $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                    $param1=$sqlcmd.Parameters.Add("@WorkflowId", [System.Data.SqlDbType]::int)
                    $param1.Value=$WorkflowId

                    $param1=$sqlcmd.Parameters.Add("@DockerFound", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$DockerFound.tostring()
                    
                    $param1=$sqlcmd.Parameters.Add("@ArtifactoryFound", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$ArtifactoryFound.tostring()

                    $param1=$sqlcmd.Parameters.Add("@NugetFound", [System.Data.SqlDbType]::NChar)
                    $param1.Value=$NugetFound.tostring()

                    $param1=$sqlcmd.Parameters.Add("@ArtifactoryPath", [System.Data.SqlDbType]::NVarChar)
                    $param1.Value=$ArtifactoryPath

                    $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                    $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                    $result = $SqlCmd.ExecuteNonQuery()

                    $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                    $SQLConnection.Close()
                
                }

            }
        }                       
    }

    Write-Host
    Write-Host "**************" 
    Write-Host "Repository Artifacts"
    Write-Host "---------------"

    $Artifacts = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/artifacts') -Method GET -Headers $headers

    Write-Host Number of Artifacts: $Artifacts.total_count

    foreach($Artifact in $Artifacts.artifacts)
    {
        Write-Host $Artifact.name
    }

    <#if($Artifacts.total_count -ne 0) { exit }

    if($WriteToSQL)
    {

        $SQLConnection.ConnectionString=$SQLConnectionString
        $SQLConnection.Open()

        $SqlCmd.Dispose()
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = "proc_InsertWorkflowProperties"
        $SqlCmd.Connection = $SqlConnection
        $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

        $param1=$sqlcmd.Parameters.Add("@WorkflowId", [System.Data.SqlDbType]::int)
        $param1.Value=$WorkflowId

        $param1=$sqlcmd.Parameters.Add("@DockerFound", [System.Data.SqlDbType]::NChar)
        $param1.Value=$DockerFound.tostring()
                    
        $param1=$sqlcmd.Parameters.Add("@ArtifactoryFound", [System.Data.SqlDbType]::NChar)
        $param1.Value=$ArtifactoryFound.tostring()

        $param1=$sqlcmd.Parameters.Add("@NugetFound", [System.Data.SqlDbType]::NChar)
        $param1.Value=$NugetFound.tostring()

        $param1=$sqlcmd.Parameters.Add("@ArtifactoryPath", [System.Data.SqlDbType]::NVarChar)
        $param1.Value=$ArtifactoryPath

        $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
        $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
        $result = $SqlCmd.ExecuteNonQuery()

        $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

        $SQLConnection.Close()
                
    }#>

    Write-Host
    Write-Host "******************" 
    Write-Host "Repository Secrets"
    Write-Host "------------------"
    Write-Host

    $Secrets = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/actions/secrets') -Method GET -Headers $headers

    if($Secrets.total_count -ne 0)
    {
        for ( $index = 0; $index -lt $Secrets.total_count; $index++ ) {

        Write-Host Secret: $Secrets.secrets[$index].name   
        
        }
    }

    Write-Host Repo name is $repo.name

    Write-Host
    Write-Host "**************" 
        

    try{
        $RepositoryContents = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/contents') -Method GET -Headers $headers       
    }
    catch{
    }
        

    Write-Host
    Write-Host "**************" 
    Write-Host "Branches for this repository."
    Write-Host "--------------"

    if($RepoBranches -eq $null) {
        Write-Host There are no branches for this repository.
    }
    else {
        foreach ($branch in $RepoBranches)
        {
            Write-Host 
            Write-Host "***************************************************************************" 
            Write-Host The branch name is $branch.name
            Write-Host "---------------------------------------------------------------------------"

            if($branch.name.Contains("feature")) {

                $PossibleFeatureBranch=$true

                Write-Host
                Write-Host "******************************************" 
                Write-Host $branch.name is a potential Feature branch.
                Write-Host "------------------------------------------"
                Write-Host
            }
            else{

                $PossibleFeatureBranch=$false

            }

            if($WriteToSQL)
            {

                $SQLConnection.ConnectionString=$SQLConnectionString
                $SQLConnection.Open()

                $SqlCmd.Dispose()
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $SqlCmd.CommandText = "proc_InsertBranch"
                $SqlCmd.Connection = $SqlConnection
                $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
                $param1.Value=$RepositoryId

                $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
                $param1.Value=$branch.name
            
                $param1=$sqlcmd.Parameters.Add("@PossibleFeatureBranch", [System.Data.SqlDbType]::NChar)
                $param1.Value=$PossibleFeatureBranch.tostring()
                
                $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                $result = $SqlCmd.ExecuteNonQuery()

                $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                $SQLConnection.Close()
                
            }

            
            if($branch.name.Contains("master")) {
                $PossibleMasterBranch=$true

                Write-Host
                Write-Host "******************************************" 
                Write-Host $branch.name is a potential Master branch.
                Write-Host "------------------------------------------"
                Write-Host
            }
            else{
                $PossibleMasterBranch=$false
            }

            if($WriteToSQL)
            {

                $SQLConnection.ConnectionString=$SQLConnectionString
                $SQLConnection.Open()

                $SqlCmd.Dispose()
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $SqlCmd.CommandText = "proc_InsertBranch"
                $SqlCmd.Connection = $SqlConnection
                $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
                $param1.Value=$RepositoryId

                $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
                $param1.Value=$branch.name
            
                $param1=$sqlcmd.Parameters.Add("@PossibleMasterBranch", [System.Data.SqlDbType]::NChar)
                $param1.Value=$PossibleMasterBranch.tostring()
                
                $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                $result = $SqlCmd.ExecuteNonQuery()

                $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                $SQLConnection.Close()
                
            }

            if($branch.name.Contains("main")) {
                $PossibleMainBranch=$true

                Write-Host
                Write-Host "******************************************" 
                Write-Host $branch.name is a potential Main branch.
                Write-Host "------------------------------------------"
                Write-Host
            }
            else{
                $PossibleMainBranch=$false
            }

            if($WriteToSQL)
            {

                $SQLConnection.ConnectionString=$SQLConnectionString
                $SQLConnection.Open()

                $SqlCmd.Dispose()
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $SqlCmd.CommandText = "proc_InsertBranch"
                $SqlCmd.Connection = $SqlConnection
                $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
                $param1.Value=$RepositoryId

                $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
                $param1.Value=$branch.name
            
                $param1=$sqlcmd.Parameters.Add("@PossibleMainBranch", [System.Data.SqlDbType]::NChar)
                $param1.Value=$PossibleMainBranch.tostring()
                
                $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                $result = $SqlCmd.ExecuteNonQuery()

                $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                $SQLConnection.Close()
                
            }

            if($branch.name.Contains("dev")) {
                $PossibleDevBranch=$true

                Write-Host
                Write-Host "******************************************" 
                Write-Host $branch.name is a potential Dev branch.
                Write-Host "------------------------------------------"
                Write-Host
            }
            else{
                $PossibleDevBranch=$false
            }

            if($WriteToSQL)
            {

                $SQLConnection.ConnectionString=$SQLConnectionString
                $SQLConnection.Open()

                $SqlCmd.Dispose()
                $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $SqlCmd.CommandText = "proc_InsertBranch"
                $SqlCmd.Connection = $SqlConnection
                $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
                $param1.Value=$RepositoryId

                $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
                $param1.Value=$branch.name
            
                $param1=$sqlcmd.Parameters.Add("@PossibleDevBranch", [System.Data.SqlDbType]::NChar)
                $param1.Value=$PossibleDevBranch.tostring()
                
                $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                $result = $SqlCmd.ExecuteNonQuery()

                $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                $SQLConnection.Close()
                
            }

            Write-Host
            Write-Host "********************************" 
            Write-Host Protection rules for this branch.
            Write-Host "--------------------------------"
            Write-Host
        
            try
            {
                $ProtectionRule = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/branches/' + $branch.name + '/protection') -Method GET -Headers $headers -ErrorAction Ignore
            }
            catch
            {
                #Write-Host $_.Exception.Response
                $ProtectionRule = ""
            }
        
            if ($ProtectionRule -eq "")
            {
                Write-Host This branch is not protected.
            }
            else
            { 
                Write-Host "*************************"
                Write-Host  This branch is protected.
                Write-Host "-------------------------"

                $EnforceAdmins = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/branches/' + $branch.name + '/protection/enforce_admins') -Method GET -Headers $headers

                Write-Host Enforce admins: $EnforceAdmins.enabled

                $index = 0

                $RequiredPullRequestReviews = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/branches/' + $branch.name + '/protection/required_pull_request_reviews') -Method GET -Headers $headers
            
                Write-Host Required pull request reviews: $RequiredPullRequestReviews.required_approving_review_count
                Write-Host Dismiss stale reviews: $RequiredPullRequestReviews.dismiss_stale_reviews
                Write-Host Required status checks: $ProtectionRule.required_status_checks.checks.Count
                Write-Host Allow force pushes: $ProtectionRule.allow_force_pushes.enabled
                Write-Host Allow deletions: $ProtectionRule.allow_deletions.enabled
                Write-Host Require signatures: $ProtectionRule.required_signatures.enabled
                

                if($WriteToSQL)
                {

                    $SQLConnection.ConnectionString=$SQLConnectionString
                    $SQLConnection.Open()

                    $SqlCmd.Dispose()
                    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
                    $SqlCmd.CommandText = "proc_InsertBranchProtection"
                    $SqlCmd.Connection = $SqlConnection
                    $SqlCmd.CommandType = [System.Data.CommandType]'StoredProcedure';

                    $param1=$sqlcmd.Parameters.Add("@RepoId", [System.Data.SqlDbType]::int)
                    $param1.Value=$RepositoryId

                    $param1=$sqlcmd.Parameters.Add("@Name", [System.Data.SqlDbType]::NVarChar)
                    $param1.Value=$branch.name
            
                    $param1=$sqlcmd.Parameters.Add("@EnforceAdmins", [System.Data.SqlDbType]::NChar)
                    $param1.Value= if ($EnforceAdmins.enabled -eq $null) { "" } else { $EnforceAdmins.enabled.ToString() }
                    
                    $param1=$sqlcmd.Parameters.Add("@RequiredPRReviews", [System.Data.SqlDbType]::int)
                    $param1.Value=$RequiredPullRequestReviews.required_approving_review_count

                    $param1=$sqlcmd.Parameters.Add("@DismissStaleReviews", [System.Data.SqlDbType]::NChar)
                    $param1.Value= if ($RequiredPullRequestReviews.dismiss_stale_reviews -eq $null) { "" } else { $RequiredPullRequestReviews.dismiss_stale_reviews.ToString() }

                    $param1=$sqlcmd.Parameters.Add("@AllowForcePushes", [System.Data.SqlDbType]::NChar)
                    $param1.Value= if ($ProtectionRule.allow_force_pushes.enabled -eq $null) { "" } else { $ProtectionRule.allow_force_pushes.enabled.ToString() }

                    $param1=$sqlcmd.Parameters.Add("@AllowDeletions", [System.Data.SqlDbType]::NChar)
                    $param1.Value= if ($ProtectionRule.allow_deletions.enabled -eq $null) { "" } else { $ProtectionRule.allow_deletions.enabled.ToString() }

                    $param1=$sqlcmd.Parameters.Add("@RequireSignatures", [System.Data.SqlDbType]::NChar)
                    $param1.Value= if ($ProtectionRule.required_signatures.enabled -eq $null) { "" } else { $ProtectionRule.required_signatures.enabled.ToString() }

                    $paramReturn = $sqlCmd.Parameters.Add("@ReturnValue", [System.Data.SqlDbType]::Int)
                    $paramReturn.Direction = [System.Data.ParameterDirection]::ReturnValue
        
                    $result = $SqlCmd.ExecuteNonQuery()

                    $returnValue = $sqlCmd.Parameters["@ReturnValue"].Value

                    $SQLConnection.Close()
                
                }
            }

            Write-Host

            # TODO Group the names of the authors of all commits.
            Write-Host  Here is the latest commit information:
            Write-Host "--------------------------------------" 

            Write-Host       
        
            try{
                $commits = Invoke-RestMethod ('https://api.github.com/repos/' + $OrgName + '/' + $repo.name + '/commits/' + $branch.name) -Method GET -Headers $headers
            }
            catch{
            }

            Write-Host $commits[0].commit.author.name
            Write-Host $commits[0].commit.author.date
            Write-Host $commits[0].commit.message
            Write-Host

            
        }            

        Write-Host Number of workflows: $Workflows.total_count
        Write-Host Number of workflows based on the counter: $WorkflowsCount
        Write-Host "**********************************************"
        Write-Host  Processing of repository complete.
        Write-Host "----------------------------------------------" 

        Write-Host 
        Write-Host
        Write-Host "*************************************************"
        Write-Host
        Write-Host
    } 


    Write-Host
    Write-Host Total number of workflows found: $WorkflowsCount
    #Dispose of objects after the repository run
    Write-Host "Closing connections and disposing of objects."

    if($WriteToSQL){
        $SqlCmd.Dispose()
        $SQLConnection.Dispose()
    }
