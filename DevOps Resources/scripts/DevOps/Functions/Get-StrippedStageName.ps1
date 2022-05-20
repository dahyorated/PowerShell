<#
.Synopsis
Get the environment portion of a stage name.

.Description
This gets the environment portion of a stage name.
It supports standard conforming stage names (e.g., 'DEV-EUW') and old-style names (e.g., 'euwdev').

If the stage name is for a DR region (i.e., it is not 'EUW'), it returns 'skipDR'.

.Paramter StageName
This is the stage name.

.Example
$environment = Get-StrippedStageName 'UAT-EUW';

This sets $environment to 'UAT'.

.Example
$environment = Get-StrippedStageName 'euwuat';

This sets $environment to 'UAT'.

#>
Function Get-StrippedStageName
{
	[CmdletBinding()]
	param(
		[string]$StageName
	)
	$strippedStageName = $StageName.ToLower().Trim();
	$pathMatches = [regex]::Match($strippedStageName,"([a-z]{3})-([a-z]{3})$");
	if ($pathMatches.Groups.Count -eq 3)
	{
		$environment = $pathMatches.Groups[2].Value;
		if ($environment -eq 'euw')
		{
			# process new standard
			$strippedStageName =  $pathMatches.Groups[1].Value;
		}
		else
		{
			$strippedStageName = "skipDR";
		}
	}
	else
	{
		#Write-Verbose "pathMatches Count: $($pathMatches.Count)";
		# process old variants
		$strippedStageName = $strippedStageName.Replace("-all","").Replace("euw","").Replace("ctp ","").Replace("emw","");
	}
	return $strippedStageName;
}
