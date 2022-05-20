Function Get-KeyVaultName
{
	param(
		[ValidateSet('Development','QA')]
		[string]$Environment
	)
	$keyVaultName = switch ($Environment)
	{
		Development
		{
			"EUWDGTP005AKV01"
		}
		QA
		{
			"EUWQGTP007AKV01"
		}
		Default
		{
			"NA"
		}
	}
	return $keyVaultName;
}
