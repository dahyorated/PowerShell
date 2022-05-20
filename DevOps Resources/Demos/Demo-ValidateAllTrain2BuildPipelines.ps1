Push-Location C:\EYdev\devops\pipelines;
$t2 = gci .\BuildDefinitions\Train2\ -Filter '*.json';
$t2 | Foreach-Object { 
	$pipelineName = [System.IO.Path]::GetFileNameWithoutExtension($_.name);
	Validate-BuildDefinition -PipelineName $pipelineName;
};
Pop-Location;
