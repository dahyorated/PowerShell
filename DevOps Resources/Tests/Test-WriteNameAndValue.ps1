Push-Location C:\EYdev\devops\scripts;
Import-Module -Name $PWD\DevOps -Force;
Write-NameAndValue "Name0";
Write-NameAndValue "Name1" "Value1";
Write-NameAndValue -Name "Name2" -Value "Value2";
Write-NameAndValue -Value "Value3" -Name "Name3";
Write-NameAndValue "Name4" 4.3;
Write-NameAndValue "Name5" (@{Name="xyzzy";Value=3.14} | Out-String);
Pop-Location;
