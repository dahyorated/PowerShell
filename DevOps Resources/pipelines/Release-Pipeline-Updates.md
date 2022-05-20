# Release Pipeline Updates

# Get Pipelines Under Path
This command retrieves, as JSON, all of the release definitions under the `\CTP` folder.
```PowerShell
$rdsAsString = [string](az pipelines release definition list --query "[?path == '\CTP']");
$rds = ConvertFrom-JSON -InputObject $rdsAsString;
```

The next step is to retrieve the details of each pipeline definition using the identifiers (see 'id') in `$rds`.
```PowerShell
ForEach ($rd in $rds)
{
	$rdDetailsAsString = [string](az pipelines release definition show --id $rd.id);
	$rdDetails = ConvertFrom-Json -InputObject $rdDetailsAsString;
	ForEach ($nextEnvironment in $rdDetails.environments)
	{
		Write-Host ("Environment[{0}]: {1}" -f $nextEnvironment.id,$nextEnvironment.name);
	}
}
```

The `daysToRelease` element is a bit-wise `or` of the days of the week.
- Sunday is the high-order bit (*i.e.*, 1000000)
- Saturday is the low-order bit (*i.e.*, 0000001)
- A value of 127 (*i.e.*, 1111111) means all days
- A value of 62 (*i.e.*, 0111110) means all week days
