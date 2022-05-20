Push-Location "C:\EYdev\devops\pipelines";
#Get-ReleaseDefinitionStatus -QueryPaths @("\CTP");
#Get-ReleaseStatus -Force -NoExcel;
#Get-ReleaseStatus -NoExcel;
#Get-ReleaseStatus -SkipRefresh;
Get-ReleaseStatus -NoExcel -ReleaseOnly;
Pop-Location;
