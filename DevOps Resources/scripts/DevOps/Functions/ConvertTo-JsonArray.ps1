Function ConvertTo-JsonArray
{
<#
	.Synopsis
	Format a delimited set of data into a JSON array.

	.Description
	The ConvertTo-JsonArray function formats the -SetData delimited set of data into a JSON array.

	.Parameter SetData
	This is the set of data to be converted.
	- Sets are delimited by -SetDelimiter which defaults to '|'.
	- Items are delimited by -ItemDelimiter which defaults to ','.

	.Parameter SetFormat
	This is the format for a set. The format has place holder for each item in a set.

	.Parameter TokenDelimiters
	This is a pair of delimiters for a token.

	.Parameter SetDelimiter
	This is the delimiter used between sets.

	.Parameter ItemDelimiter
	This is the delimiter used between items.

	.Outputs
	The output is a JSON array of all the set data using the set format.

	.Example
	ConvertTo-JsonArray -SetData "x,y,z|a,b,c" -SetFormat '"<<0>>":["<<1>>","<<2>>"]'

#>
	[CmdletBinding()]
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline)]
		[string]$SetData,
		[Parameter(Mandatory=$true)]
		[string]$SetFormat,
		[Parameter(Mandatory=$false)]
		[string[]]$TokenDelimiters = @('<<','>>'),
		[Parameter(Mandatory=$false)]
		[string]$SetDelimiter = "|",
		[Parameter(Mandatory=$false)]
		[string]$ItemDelimiter = ","
	)
	$jsonArrayFormat = "[#]";
	$formattedSetData = @();
	$beginToken = $TokenDelimiters[0];
	$endToken = $TokenDelimiters[1];
	$sets = $SetData.Split($SetDelimiter);
	# Get the count of tokens
	$tokenCount = 0;
	$foundToken = $true;
	do
	{
		$nextToken = "{0}{1}{2}" -f $beginToken,$tokenCount,$endToken;
		if ($SetFormat.Contains($nextToken))
		{
			$tokenCount++;
		}
		else
		{
			$foundToken =$false;
		}
	}
	while ($foundToken);
	foreach ($set in $sets)
	{
		$setDetails = $set.Split($ItemDelimiter);
		$formattedSet = $SetFormat;
		for ($i=0;$i -lt $tokenCount; $i++)
		{
			$nextToken = "{0}{1}{2}" -f $beginToken,$i,$endToken;
			$formattedSet = $formattedSet.Replace($nextToken,$setDetails[$i]);
		}
		$formattedSetData += $formattedSet;
	}
	$jsonArray = $jsonArrayFormat.Replace("#",($formattedSetData -join ","));
	return $jsonArray;
}
