Function Remove-EndsWith
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNull()]
        [string]$InputString,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNull()]
        [string]$EndsWith
    )
    if ($InputString.EndsWith($EndsWith))
    {
        return $InputString.Substring(0,$InputString.Length-$EndsWith.Length);
    }
    else
    {
        return $InputString;
    }
}
