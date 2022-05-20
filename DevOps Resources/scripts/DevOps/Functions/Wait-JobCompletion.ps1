Function Wait-JobCompletion
{
	param(
		[Parameter(Mandatory=$True)]
		[int]$jobId,
		[Parameter(Mandatory=$False)]
		[int]$SleepIntervalInSeconds = 15,
		[Parameter(Mandatory=$False)]
		[int]$MaxWaitInSeconds = 600,
		[switch]$skipFirstSleep,
		[switch]$noExit
	)
	$jobStatusuri = "https://gtpprovisioning.sbp.eyclienthub.com/api/JobStatus?code=N7Z6DPfxl6pZOt8RyTjSdQHuiYq7xRWIYAepJm5GaqmMj//BoLDLbg==";
	Write-Host "Waiting for Job ID: $($jobId)";
	$jobStatusBodyParam =   @{'jobid' = $jobid};
	$jobStatusBodyJson = $jobStatusBodyParam  | ConvertTo-Json -Depth 100 -Compress;
	$maxIterations = [int]($MaxWaitInSeconds / $SleepIntervalInSeconds);
	$i = 1;
	if ($skipFirstSleep)
	{
		$i = 0;
	}
	do{ 
		if ($i -ne 0)
		{
			Start-Sleep $SleepIntervalInSeconds;
		}
		Write-Host "Checking after $($i * $SleepIntervalInSeconds) seconds.";
		try
		{
			$global:jobStatusResponse = Invoke-RestMethod -Uri $jobStatusuri -Method Post -ContentType "application/json"  -Body $jobStatusBodyJson;
			$global:jobMsg = $jobStatusResponse.msg;
			$jobMsgStatus = $jobMsg.status;
			Write-Host ("Status: {0}" -f $jobMsg.status);
		}
		catch [System.Net.WebException]
		{
			Write-Host "WebException occurred."
			$global:jobError = $_;
			$jobMsgStatus = 'Failed';
			break;
		}
		catch
		{
			Write-Host "Exception occurred."
			$global:jobError = $_;
			$jobMsgStatus = 'Failed';
			break;
		}
		if ($jobMsgStatus -eq 'completed' -or $jobMsgStatus -eq 'OK' -or $jobMsgStatus -eq 'Failed')
		{
			Write-Verbose $jobMsg | ConvertTo-Json -Depth 100 -Compress;
			$i = $maxIterations;
			break;
		}
		$i++;
	}
	while ($i -le $maxIterations);
	if ($jobMsgStatus -eq 'Failed')
	{
		if ($noExit)
		{
			if ($jobError.ErrorDetails.Message -eq $null)
			{
				$errorMessage = [PSCustomObject]@{
					exception = $jobError.Exception
					};
			}
			else
			{
				$errorMessage = ($jobError.ErrorDetails.Message | ConvertFrom-Json);
			}
			$global:jobMsg = [PSCustomObject]@{
				status = $jobMsgStatus
				errorMessage = $errorMessage
			};
			return $jobMsg;
		}
		else
		{
			Write-Host "Error: $($jobError)";
			Exit;
		}
	}
	return $jobMsg;
}
