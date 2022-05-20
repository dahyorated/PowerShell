Push-Location C:\EYdev\devops\scripts;
Import-Module -Name $PSScriptRoot\..\DevOps -Force -Verbose:$false;
$secret = New-KVSecret -KeyVaultName XXX -SecretName configServiceSecret -SecretValueText "8f9c422c-be06-4f7e-8aeb-ef5f2fc76790";
Write-NameAndValue "Secret" $secret;
Pop-Location;
