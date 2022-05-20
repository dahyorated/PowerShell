
The scripts in this folder are used to verify Boardwalk resources have been provisioned correctly and enable lockdown of traffice to an app service from the WAF.

Here are steps to follow when an APAC Boardwalk instance is requested for client;

1. Create tasks for BW stories
    * Validate WAF Configutation
    * Create DNS Record
    * Lockdown App Service to WAF
    * Smoke Test DNS Name
    * Notify Client Team and Request Feature flag

2. Connect to the prod clientDB euwpgtp018sql01.database.windows.net,1433 and run the following query. .\devops\T-SQL\Get BW Client Information.sql

3. Verify client id and names match story

4. Copy the Smoke test column to the appropriate Smoke Test DNS Name task for a client.

5. Copy AppService to the "Lockdown App Service to WAF" task

6. Validate WAF Configuration - The following script will confirm the following configurations for a list clients;
    * App service
    * Application Gateway Listener
    * Application Gateway Backend pool
    * Application Gateway Ruleset
 

~~~
.\Confirm-BoardWalkConfiguration.ps1 -ClientIds @("1303", "1310", "1327") -ApplicationGatewayName EUWPGTP018AAG06 -TenantSubsriptionName "EY-CTSBP-PROD-TAX-GTP_TENANT-07-39861197"
~~~

7. Run the .\Add-AppServicePolicyRestrictions.ps1 script. This will verify that the app services exist, BW has been deployed, and restrict access from the WAF only.

~~~ 
.\Add-AppServicePolicyRestrictions.ps1 -AppServices @("EUWDGTP395WAP03") -SubscriptionId "9114d4ef-3fee-42c0-8edf-4f6d8273d3dd" -ClientId "347e83e0-ca4a-486d-8fbe-bed51d902a4a" -ClientSecret "R5Nb#Zr!Wsd4H8P11fB166VniL183I2g" -TenantId "5b973f99-77df-4beb-b27d-aa0c70b8482c" -VnetSubnetResourceId "subscriptions/5aeb8557-cab7-41ac-8603-9f94ad233efc/resourceGroups/GT-WEU-GTP-CORE-DEV-RSG/providers/Microsoft.Network/virtualNetworks/EUWSDGTPVNT02/subnets/EUWDGTP005SBN02"

~~~
 

8. Create DNS Records - Run the python script per Gateway as the address will change. 

~~~
.\DNS_mass_applier.py
~~~

9. Smoke test DNS Names
    * Internal (on the VPN) and external DNS name
    * Navigating directly to the app service returns a 403
