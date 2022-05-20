# Source: devops\scripts\InlineScripts\Get-DevOpsFromContainer.ps1
$storageAccount = 'EUWDGTP005STA01';
$containerName = 'devops';
$zipFileName = 'scripts.zip';
$destinationFolder = "{0}\scripts\" -f $env:AGENT_TOOLSDIRECTORY;
Write-Output ("destinationFolder: {0}" -f $destinationFolder);
$zipFile = "{0}\{1}" -f $destinationFolder,$zipFileName;
Write-Output ("zipFile: {0}" -f $zipFile);
if (Test-Path $destinationFolder)
{
  Remove-Item -Path $destinationFolder -Recurse -Force;
}
New-Item -ItemType "directory" -Path $destinationFolder;
$storage = Get-AzStorageAccount -ResourceGroupName GT-WEU-GTP-CORE-DEV-RSG -Name $storageAccount;
$context = $storage.Context;
$files = Get-AzStorageBlob -Container $containerName -Context $storage.Context;
[array]$files = Get-AzStorageBlob -Container $containerName -Context $storage.Context -Blob $zipFileName;
$count = $files.Count;
if ($count -eq 1)
{
  $fileName = $files[0].Name;
  $file = Get-AzStorageBlobContent -Blob $fileName -Container $containerName -Destination $destinationFolder -Context $context;
  if ($null -ne $file)
  {
    Write-Output "Copied '$fileName'.";
    if ($env:IS_PSCX_ARCHIVE -eq $true)
    {
      Expand-Archive -Path $zipFile -OutputPath $destinationFolder;
    }
    else
    {
      Expand-Archive -Path $zipFile -DestinationPath $destinationFolder;
    }
    Write-Output "Expanded '$fileName'.";
    Remove-Item -Path $zipFile -Force;
    if ("$(library.debug)" -eq "true")
    {
      Get-ChildItem $destinationFolder -Recurse;
    }
  }
  else
  {
    Write-Error "Copy of '$fileName' failed.";
  }
}
else
{
    Write-Error ("'{0}' is missing from '{1}' container on '{2}." -f $zipFileName,$containerName,$storageAccount);
}
Write-Output "##vso[task.setvariable variable=ScriptsLoaded;]True";
