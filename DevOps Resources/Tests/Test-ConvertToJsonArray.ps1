Push-Location C:\EYdev\devops\scripts;
Import-Module -Name .\DevOps -Force;
$setData = 'x,y,z|a,b,c';
$setFormat = '"<<0>>":["<<1>>","<<2>>"]';
$setData | ConvertTo-JsonArray -SetFormat $setFormat;
Pop-Location;
