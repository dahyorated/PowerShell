Function Invoke-VerboseCommandX {
param(
    [Parameter(Mandatory=$true)]
    [ScriptBlock]$Command,
    [Parameter(Mandatory=$false)]
    [string] $StderrPrefix = "",
    [Parameter(Mandatory=$false)]
    [int[]]$AllowedExitCodes = @(0,128)
)
    Get-Variable -Scope Script;
    $Script = $Command.ToString();
    $Captures = Select-String '\$(\w+)' -Input $Script -AllMatches;
    ForEach ($Capture in $Captures.Matches)
    {
        $Variable = $Capture.Groups[1].Value;
        $Value = Get-Variable -Name $Variable -ValueOnly;
        $Script = $Script.Replace("`$$($Variable)", $Value);
    }
    Write-Output $Script.Trim();
    If ($null -ne $script:ErrorActionPreference)
	{
        $backupErrorActionPreference = $script:ErrorActionPreference;
    } ElseIf ($null -ne $ErrorActionPreference)
	{
        $backupErrorActionPreference = $ErrorActionPreference;
    }
    $script:ErrorActionPreference = "Continue";
    try
    {
        & $Command 2>&1 | ForEach-Object -Process `
        {
            if ($_ -is [System.Management.Automation.ErrorRecord])
            {
                "$StderrPrefix$_";
            }
            else
            {
                "$_";
            }
        }
        if ($AllowedExitCodes -notcontains $LASTEXITCODE)
        {
            throw "Execution failed with exit code $LASTEXITCODE";
        }
    }
    finally
    {
        $script:ErrorActionPreference = $backupErrorActionPreference;
    }
}
