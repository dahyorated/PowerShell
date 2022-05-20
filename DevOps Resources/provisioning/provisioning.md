[[_TOC_]]

# provisioning Folder
This folder contains the JSON files used to provision:
- App Service Plans
- App Services, and
- Routed Databases.

## Templates
This folder contains the templates use to create a service/client specific set of JSON parameter files.
- [Create App Service Plan and Service](./Templates/Create-AppServicePlan.json)
- [Create Routed Database](./Templates/Create-ClientDatabase.json)

## Template Tokens
This table shows the tokens in the [templates](#templates) and the values that replace them.
Tokens are shown in the templates as `<<xxx>>` where "xxx" is the token name.

| Name | Value | Example |
| ---- | ----- | ------- |
| Service Name | This is the name of the service. | Payment Service |
| Location | This is the Azure location for the deployment. | westeurope |
| Client ID | This is the integer client ID. | 3 |
| GTPnnn | This is the deployment ID where "nnn" is the ID for the regions and client. | GTP005 |
| Environment | This is the Ansible environment which is one of "Development, QA, .." | Development |
