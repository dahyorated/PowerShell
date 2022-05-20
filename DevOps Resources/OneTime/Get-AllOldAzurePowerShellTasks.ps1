$files = Get-ChildItem "C:\EYdev\devops\pipelines\ReleaseDefinitions\CTP" -Filter *.json;
$files | Foreach-Object {
	$relDef = Get-Content $_.FullName | ConvertFrom-Json;
	$showRelDef = $true;
	$defName = $relDef.name;
	$relDef.environments | Foreach-Object {
		$stageName = $_.name;
		$showStageName = $true;
		$_.deployPhases | Foreach-Object {
			$_.workflowTasks | ForEach-Object {
				$wft = $_;
				if ($wft.taskId -eq '72a1931b-effb-4d2e-8fd8-f8472a07cb62')
				{
					if ($wft.version -ne '4.*')
					{
						if ($showRelDef)
						{
							$showRelDef = $false;
							Write-Output $defName;
						}
						if ($showStageName)
						{
							$showStageName = $false;
							Write-Output "==>`t$stageName";
						}
						$message = "`t==>`t{0}: Version {1}" -f $_.name,$_.version;
						Write-Output $message;
					}
				}
			};
		};
	};
}
