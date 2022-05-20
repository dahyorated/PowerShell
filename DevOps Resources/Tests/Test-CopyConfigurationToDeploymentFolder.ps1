Push-Location C:\EYdev\devops;
$ENV:RELEASE_DEPLOYMENT_REQUESTEDFOREMAIL = 'Brad.Friedlander@ey.com';
$ENV:RELEASE_DEPLOYMENT_REQUESTEDFOR = 'Brad Friedlander';
$ENV:AGENT_RELEASEDIRECTORY = "C:\EYdev\test\LocalRepo";
$ENV:SUBSCRIPTIONID = "5aeb8557-cab7-41ac-8603-9f94ad233efc";
$ENV:RESOURCEGROUP = "GT-WEU-GTP-CORE-DEV-RSG";
$stageName = "QAT-EUW";
$environment = "euwqa";
$source = "$PWD\Tests\Data\Config";
$destination = "https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_git/Configuration";
Copy-ConfigurationToDeploymentFolder `
	-StageName $stageName `
	-Environment $environment `
	-Source $source `
	-Destination $destination `
	#-Verbose `
	;
Pop-Location;
