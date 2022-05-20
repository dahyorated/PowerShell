Push-Location C:\EYdev\devops\provisioning;
New-AppServicePlan -AppSvcPlanFullPathname .\ClientMasterDataService-UAT-EUW.json -StageName UAT-EUW;
Pop-Location;
