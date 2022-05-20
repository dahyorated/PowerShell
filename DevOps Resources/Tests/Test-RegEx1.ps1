$stageNames = @("qaemw","euwqa","nonsense");
foreach ($stageName in $stageNames)
{
	$global:matches =  [regex]::Match($stagename,"^.*(dev|qa|uat|perf|stage|prod).*$");
	#$matches;
	$matchCount = $matches.Count;
	#$matchCount;
	for ($i = 0; $i -lt $matchCount; $i++)
	{
		#Write-Host "Match $i";
		#$matches[$i];
		$groups =$matches.Groups;
		$groupCount = $groups.Count;
		for ($j = 0; $j -lt $groupCount; $j++)
		{
			Write-Host "Group $i,$j $($groups[$j].Value)";
			#$groups[$j];
		}
	}
	$strippedStageName = $matches.Groups[1].Value;
	Write-Host "Stripped stage name is '$strippedStageName'.";
};
