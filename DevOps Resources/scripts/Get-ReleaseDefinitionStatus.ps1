<#
.SYNOPSIS
Creates a JSON file with the current status of all release definitions.

.DESCRIPTION
The Get-ReleaseDefinitionStatus script creates a JSON file with the current status of all release definitions found in -QueryPath.
The JSON file contains one class per release definition.
The class information includes:
- The release definition name;
- The build definition name;
- The database name (if it is for a database); and
- The deployment date/time and app service name for the most recent successful deployment in each environment.

.PARAMETER JsonFile
This is the pathname of the resulting JSON file.

.PARAMETER QueryPath
This is the path for the release definitions of interest.

.PARAMETER Account
This is the Azure DevOps account.

.PARAMETER ProjectName
This is the Azure DevOps project to search.

.PARAMETER Token
This is a personal access token that has full read access to all required Azure DevOps information.
This currently defaults to a personal access token.

.Parameter ShowApprovals
If specified, the approvers for each stage are shown.

.EXAMPLE
Get-ReleaseDefinitionStatus -JsonFile "$PWD\ReleaseDefinitionStatus.json";

This get the status of release definitions and writes the JSON file to "$PWD\ReleaseDefinitionStatus.json".

#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$false,ValueFromPipeline)]
	[ValidateScript({
		if(!($_ | Split-Path | Test-Path) )
		{
			throw "Folder for '$_' does not exist.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$JsonFile = "$pwd\ReleaseDefinitionStatus.json",
	[Parameter(Mandatory=$false)]
	[string[]]$QueryPaths = @("\CTP"),
	[Parameter(Mandatory=$false)]
	[string]$Account = "eyglobaltaxplatform",
	[Parameter(Mandatory=$false)]
	[string]$ProjectName = "Global Tax Platform",
	[Parameter(Mandatory=$false)]
	[string]$token = ${env:SYSTEM_ACCESSTOKEN},
	[switch]$ShowApprovals
)

Class RdsState
{
	[bool]$ShouldProcess
	[string]$StageName
	[PSCustomObject]$Rds

	RdsState([PSCustomObject]$rdStatus,[string]$envName)
	{
		$this.StageName = Get-StrippedStageName $envName;
		$this.ShouldProcess = $true;
		switch ($this.StageName)
		{
			'dev' {$this.Rds = $rdStatus.dev; break;}
			'dmo' {$this.Rds = $rdStatus.dmo; break;}
			'qa' {$this.Rds = $rdStatus.qat; break;}
			'qat' {$this.Rds = $rdStatus.qat; break;}
			'uat' {$this.Rds = $rdStatus.uat; break;}
			'perf' {$this.Rds = $rdStatus.prf; break;}
			'prf' {$this.Rds = $rdStatus.prf; break;}
			'stage' {$this.Rds = $rdStatus.stg; break;}
			'stg' {$this.Rds = $rdStatus.stg; break;}
			'prod' {$this.Rds = $rdStatus.prd; break;}
			'prd' {$this.Rds = $rdStatus.prd; break;}
			'skipDR'
			{
				switch ($envName.Trim())
				{
					'DEV-USE' {$this.Rds = $rdStatus.devDr; break;}
					'STG-USE' {$this.Rds = $rdStatus.stgDr; break;}
					'PRD-USE' {$this.Rds = $rdStatus.prdDr; break;}
					default {$this.ShouldProcess = $false; $this.Rds = $null; break;}
				}
			}
			default {$this.ShouldProcess = $false; $this.Rds = $null; break;}
		}
	}
}
Function New-ReleaseDefinitionStatus()
{
	param(
		[string]$DefinitionName
	)
	return [PSCustomObject]@{
		definitionName = $DefinitionName
		buildDefinitionName = ''
		databaseName = ''
		dev = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		dmo = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		qat = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		uat = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		prf = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		stg = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		prd = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		devDr = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		stgDr = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
		prdDr = [PSCustomObject]@{
			ReleaseName = 'NA'
			DefId = 0
			ReleaseId = 0
			BuildId = 0
			BuildName = ''
			FinishedOn = ''
			AppServiceName = ''
		}
	};
}

Function Find-Project
{
	param(
		[string]$projectName
	)
	Write-Verbose ("Verify project {0} exists." -f $projectName);
	$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $coreAreaId;
	# https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
	$projectsUrl = "$($tfsBaseUrl)_apis/projects?api-version=5.1";
	$projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $authHeader;
	$allProjects = $projects.value | Sort-Object -Property name;
	foreach($project in $allProjects)
	{
		Write-Verbose "`t$($project.name)";
		if ($projectName -eq $project.name)
		{
			return;
		}
	};
	$errorMessage = "'$ProjectName' does not exist in account '$Account'. ";
	Stop-ProcessError -errorMessage $errorMessage;
}

Function Get-AppServiceName
{
	param(
		[PSCustomObject]$rds,
		[string]$stageName,
		[string]$envName
	)
	$relDefEnv = $relDefFull.environments | Where-Object name -eq $envName;
	if ($null -ne $relDefEnv)
	{
		Write-Host "`t`t$($stageName): Checking '$envName'" -ForegroundColor Cyan;
		$inputs = $relDefEnv.processParameters.inputs;
		$varAppSvcName = $relDefEnv.variables.appSvcName;
		$varBoardwalkSvcName = $relDefFull.variables.BwServiceName;
		$webAppName = $inputs | Where-Object name -eq "WebAppName";
		if ($null -ne $varBoardwalkSvcName)
		{
			$appSvcName = $varBoardwalkSvcName.value.Trim();
			Write-Host "`t`tappSvcName($stageName): $appSvcName" -ForegroundColor Cyan;
			$rds.AppServiceName = $appSvcName;
			return;
		}
		if ($null -ne $varAppSvcName)
		{
			$appSvcName = $varAppSvcName.value.Trim();
			Write-Host "`t`tappSvcName($stageName): $appSvcName" -ForegroundColor Cyan;
			$rds.AppServiceName = $appSvcName;
			return;
		}
		if ($null -ne $webAppName)
		{
			$appSvcName = $webAppName.defaultValue.Trim();
			Write-Host "`t`tappSvcName($stageName): $appSvcName" -ForegroundColor Cyan;
			$rds.AppServiceName = $appSvcName;
			return;
		}
		$wts = $relDefEnv.deployPhases[0].workflowTasks;
		if ($null -eq $wts)
		{
			return;
		}
		foreach ($wt in $wts)
		{
			$appSvcName = $wt.inputs.appServiceName;
			if (-not [string]::IsNullOrEmpty($appSvcName))
			{
				$appSvcName = $appSvcName.Trim()
				Write-Host "`t`tappSvcName($stageName): $appSvcName" -ForegroundColor Cyan;
				$rds.AppServiceName = $appSvcname;
				return;
			}
			$appSvcName = $wt.inputs.WebAppName;
			if (-not [string]::IsNullOrEmpty($appSvcName))
			{
				$appSvcName = $appSvcName.Trim()
				Write-Host "`t`tappSvcName($stageName): $appSvcName" -ForegroundColor Cyan;
				$rds.AppServiceName = $appSvcname;
				return;
			}
		}
	}
}

Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
Write-Output "JSON file will be saved in '$($JsonFile)'.";
if (Test-Path -Path $JsonFile -PathType Leaf)
{
	[System.Collections.ArrayList]$rdStatuses = Get-Content -Path $JsonFile | ConvertFrom-Json;
	# first path is assumed to have incremental updates
	$incrementalPath = $true;
	$update = $true;
}
else
{
	$rdStatuses = New-Object System.Collections.ArrayList;
	# $incrementalPath is used to apply updates to the results of the first path provided.
	# first path is assumed to be the baseline (i.e., has all pipelines)
	$incrementalPath = $false;
	$update = $false;
}
$orgUrl = "https://dev.azure.com/{0}" -f $Account;
$authHeader = New-AuthorizationHeader $token;
Find-Project -projectName $ProjectName;
Write-Output "Starting Get-ReleaseDefinitionStatus";
$tfsBaseUrl = Get-DevOpsUrl -orgUrl $orgUrl -header $authHeader -AreaId $releaseManagementAreaId;
$projectUrl = "$tfsBaseUrl$($ProjectName)";
$noMatch = $false;
$missingBaseRelease = @();
foreach ($queryPath in $QueryPaths)
{
	if ((-not $update) -and ($queryPath -match 'Through '))
	{
		$incrementalPath = $false;
	}
	$pathMatches = [regex]::Match($queryPath,".*Release ([0-9]*\.[0-9]*)$");
	$relPrefixPath = $pathMatches.Groups[1].Value;
	if ($relPrefixPath -ne '')
	{
		$relPrefixPath = "CTP\R{0}" -f $pathMatches.Groups[1].Value;
	}
	else
	{
		$relPrefixPath = "CTP";
	}
	$result = Get-AllReleaseDefinitionsByPath -Path $queryPath -Project $projectUrl -AuthHeader $authHeader;
	[array]$relDefs = $result.value;
	# BEGIN Use this to debug a single release definition.
	#[array]$relDefs = $result.value | Where-Object name -eq 'tokenservice-ctp';
	# END Use this to debug a single release definition.
	if ($relDefs.count -gt 0)
	{
		Write-Host "$($ProjectName)$($queryPath): $($relDefs.count) release definitions found" -ForegroundColor Yellow;
		$relDefs |
			Sort-Object -Property name |
			ForEach-Object {
				$global:relDef = $_;
				$relDefId = $relDef.id;
				$relDefName = $relDef.name;
				$isDatabase = $relDefName -like '*-db-ctp*';
				if ($incrementalPath)
				{
					# find a matching $rdStatus;
					$matches =  [regex]::Match($relDefName,"(.*)-[Rr][0-9]*\.[0-9]*");
					if ($matches -and ($matches.Groups.Count -eq 2))
					{
						$matchRelDefName = $matches.Groups[1].Value;
					}
					else
					{
						$matchRelDefName = $relDefName;
					}
					$matchStatuses = $rdStatuses.Where{$_.definitionName -eq $matchRelDefName};
					if ($matchStatuses -ne $null -and $matchStatuses.Count -eq 1)
					{
						$rdStatus = $matchStatuses[0];
					}
					else
					{
						$missingBaseRelease += "No match for $($relDefname)";
						$noMatch = $true;
						$rdStatus = New-ReleaseDefinitionStatus($relDefName);
					}
				}
				else
				{
					$rdStatus = New-ReleaseDefinitionStatus($relDefName);
				}
				$relDefFull = Get-ReleaseDefinitionById -ReleaseDefinitionId $relDefId -ProjectUrl $projectUrl -AuthHeader $authHeader;
				$relDefVars = $relDefFull.variables;
				if ([string]::IsNullOrWhiteSpace($rdStatus.buildDefinitionName))
				{
					$buildArtifact = $relDefFull.artifacts | Where-Object {$_.isPrimary -and ($_.type -eq 'Build')};
					$buildName = $buildArtifact.definitionReference.definition.name;
					$rdStatus.buildDefinitionName = $buildName;
				}
				Write-Host "`t$($relDefName)" -ForegroundColor White;
				if ($isDatabase -and ($rdStatus.databaseName -eq ''))
				{
					if ($null -ne $relDefVars.dbName)
					{
						Write-Verbose $relDefVars.dbName;
						$dbName = $relDefVars.dbName.value;
					}
					elseif ($null -ne $relDefVars.ServiceName)
					{
						Write-Verbose $relDefVars.ServiceName;
						$dbName = "{0}db" -f $relDefVars.ServiceName.value;
					}
					else
					{
						Write-Verbose "No database name";
						$dbName = 'NA';
					}
					Write-Host "`t`tProcessing database '$dbName'." -ForegroundColor Cyan;
					$rdStatus.databaseName = $dbName;
				}
				$result = Get-AllReleasesForDefinition $relDefId $projectUrl $authHeader;
				$rels = $result.releases;
				if ($rels.count -gt 0)
				{
					Write-Host "`t`t$($rels.count) releases found" -ForegroundColor Cyan;
					# always start with the newest releases (i.e., the highest release id)
					$rels |
						Sort-Object -Property id -Descending |
						ForEach-Object {
							$global:rel = $_;
							$relId = $rel.id;
							$relDetail = $null;
							$relName = $rel.name;
							$relStatus = $rel.status;
							if ($relStatus -ne 'active')
							{
								Write-Host ("`t`t`t{0} has status '{1}'." -f $relName,$relStatus) -ForegroundColor Magenta;
							}
							$rel.Environments |
								Sort-Object -Property name |
								ForEach-Object {
									$env = $_;
									$envName = $env.name;
									$envStatus = $env.status;
									$envFinished = $env.modifiedOn;
									if ($envStatus -eq 'succeeded')
									{
										$rdsState = [RdsState]::new($rdStatus,$envName);
										$process = $rdsState.ShouldProcess;
										$stageName = $rdsState.StageName;
										$rds = $rdsState.Rds;
										if ($process -and ($rds.AppServiceName -eq '') -and (-not $isDatabase))
										{
											Get-AppServiceName $rds $stageName $envName;
										}
										if ($process -and (($rds.ReleaseName -eq 'NA') -or ($envFinished -gt $rds.FinishedOn)))
										{
											if ($null -eq $relDetail)
											{
												$relDetail = Get-ReleaseById $relId $projectUrl $authHeader;
												[array]$relArtifacts = $relDetail.artifacts;
												$artifactCount = $relArtifacts.Count;
												for ($i =0; $i -lt $artifactCount; $i++)
												{
													if ($relArtifacts[$i].IsPrimary)
													{
														$relVersion = $relArtifacts[$i].definitionReference.version;
														break;
													}
												}
												$relBuildId = 0;
												$relBuildId = $relVersion.id;
												$relBuildName = $relVersion.name;
											}
											Write-Verbose "Replacing $relName";
											$rds.ReleaseName = "{0}\{1}" -f $relPrefixPath,$relName;
											$rds.FinishedOn = $envFinished;
											$rds.BuildId = $relBuildId;
											$rds.BuildName = $relBuildName;
											$rds.DefId = $relDefId;
											$rds.ReleaseId = $relId;
										}
									}
									Write-Verbose "`t`t$($envName): $($envStatus) Finished on $($envFinished)";
									if ($ShowApprovals -and ($null -ne $env.preDeployApprovals))
									{
										$env.preDeployApprovals | ForEach-Object {
											$approval = $_;
											if (-not $approval.isAutomated -and $approval.status -eq "approved") {
												Write-Host "`t`t`t$($relName)[$($envName):$($envStatus)] approved By $($approval.approvedBy.displayName) on $($approval.modifiedOn)" -ForegroundColor Yellow
											};
										};
									};
								};
						};
				}
				else
				{
					Write-Host "`t`tWarning: No releases found" -ForegroundColor Yellow;
				};
				if ($noMatch -or (-not $incrementalPath))
				{
					$newIndex = $rdStatuses.Add($rdStatus);
					$noMatch = $false;
				}
			};
	}
	else
	{
		Write-Host "$($ProjectName)$($queryPath): Warning - no release definitions found" -ForegroundColor Red;
	};
	# all additional paths are assumed to be a branch for releases or hot fixes
	$incrementalPath = $true;
}
$missingCount = $missingBaseRelease.Length;
if ($missingCount -gt 0)
{
	Write-Host "Missing $($missingCount) base releases." -ForegroundColor Red;
	for ($i = 0; $i -lt $missingCount; $i++)
	{
		Write-Host "`t- $($missingBaseRelease[$i])" -ForegroundColor Red;
	}
}
$rdStatuses | ConvertTo-Json -Depth 100 -Compress | Out-File -FilePath $JsonFile;
