[CmdletBinding()]
param(
	[Parameter(Mandatory=$False)]
	[ValidateScript({
		if(!($_ | Test-Path) )
		{
			throw "Folder '$_' does not exist.";
		}
		if(!($_ | Test-Path -PathType Container) )
		{
			throw "The RepositoryRootFolder argument must be a folder. Files are not allowed.";
		}
		return $true;
	})]
	[System.IO.FileInfo]$RepositoryRootFolder = "C:\EYdev\devops\pipelines",
	[string]$CsvFilename = "ApplicationSummary.csv"
)
Import-Module -Name $PSScriptRoot\DevOps -Force;
Initialize-Script $PSCmdlet.MyInvocation;
# Get release information
$global:rds = @()
$releaseFolder = "{0}\ReleaseDefinitions\CTP" -f $RepositoryRootFolder;
Get-ChildItem "$releaseFolder" -Filter *.json -Exclude "*\Control\*,*\Provisioning Only\*,*\Release *\*" -Recurse -File |
	ForEach-Object {
		$rd = ConvertFrom-Json -InputObject ([string](Get-Content $_.FullName));
		$rdName = $rd.name;
		$rd.artifacts |
			Foreach-Object {
				$artifact = $_;
				Write-Verbose ("""{0}"",{1}" -f $rd.name,$artifact.definitionReference.definition.id);
				$global:rds += New-Object PSObject -Property @{
					ReleaseName=$rd.name
					BuildId=$artifact.definitionReference.definition.id
				};
			};
	};
#$global:rds | Format-Table -AutoSize;
# Get build information
$global:bds = @()
$buildFolder = "{0}\BuildDefinitions" -f $RepositoryRootFolder;
Get-ChildItem "$buildFolder" -Filter *.json -Recurse -File |
	ForEach-Object {
		$bd = ConvertFrom-Json -InputObject ([string](Get-Content $_.FullName));
		$bdName = $bd.name;
		$bdId = $bd.id;
		if ($bd.triggers -ne $null)
		{
			$trigger = $bd.triggers | Where-Object triggerType -eq "continuousIntegration";
			$paths = $trigger.pathFilters;
			$firstPath="";
			$paths |
				Foreach-Object {
					$path = $_;
					if (-not ($path -like $firstPath))
					{
						Write-Verbose ("""{0}"",{1},""{2}""" -f $bdName,$bdId,$path);
						$global:bds += New-Object PSObject -Property @{
							BuildName=$bdName
							BuildId=$bdId
							Path=$path
						};
						if ($firstPath -eq "")
						{
							$firstPath = "{0}*" -f $path;
						}
					};
				};
		}
		elseif ($bd.process -ne $null)
		{
			Write-Verbose "'$bdName' has no trigger, checking steps."
			$phase = $bd.process.phases[0];
			$phaseName = $phase.refName;
			$steps = $phase.steps;
			Write-Verbose "$($phaseName) has $($steps.Count) steps.";
			foreach ($step in $steps) {
				$stepName = $step.displayName;
				$inputs = $step.inputs;
				if ($inputs -eq $null)
				{
					Write-Output "$($stepName) has no inputs.";
					continue;
				}
				$path = $inputs.workingDir;
				if ($path.Length -gt 0)
				{
					$global:bds += New-Object PSObject -Property @{
						BuildName=$bdName
						BuildId=$bdId
						Path=$path
					};
					break;
				};
			};
		}
		else
		{
			Write-Output "'$bdName' has no trigger."
		};
	};
;
#$global:bds | Sort-Object BuildId | Format-Table -AutoSize;
$rds |
	ForEach-Object {
		$rd = $_;
		$bdId = $rd.BuildId;
		$matchingBd = $bds | Where-Object BuildId -eq $bdId;
		$rd | Add-Member -NotePropertyName BuildName -NotePropertyValue $matchingBd.BuildName;
		$rd | Add-Member -NotePropertyName Path -NotePropertyValue $matchingBd.Path;
	};
#$global:rds | Sort-Object BuildName | Format-Table -Property BuildName,ReleaseName,Path,BuildId -AutoSize;
$global:rds |
	Sort-Object BuildName,ReleaseName |
	Select-Object BuildName,ReleaseName,Path,BuildId |
	ConvertTo-Csv -NoTypeInformation |
	Out-File "$CsvFilename";
