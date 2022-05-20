set resource-group=%1
set event-grid-name=%2
set domain-topic=%3
set grid-subsription-name=%4
set subscription-id=%5
set function-app-name=%6
set function-name=%7
set filter-parameter=%~8

@echo off
call az extension add --name eventgrid
call az eventgrid domain topic create -g %resource-group% --domain-name %event-grid-name% --name %domain-topic%

if "%filter-parameter%"=="$(filterParameter)" (call az eventgrid event-subscription create --name %grid-subsription-name% --source-resource-id /subscriptions/%subscription-id%/resourceGroups/%resource-group%/providers/Microsoft.EventGrid/domains/%event-grid-name%/topics/%domain-topic% --endpoint-type azurefunction --endpoint /subscriptions/%subscription-id%/resourceGroups/%resource-group%/providers/Microsoft.Web/sites/%function-app-name%/functions/%function-name%) else (call az eventgrid event-subscription create --name %grid-subsription-name% --source-resource-id  /subscriptions/%subscription-id%/resourceGroups/%resource-group%/providers/Microsoft.EventGrid/domains/%event-grid-name%/topics/%domain-topic% --endpoint-type azurefunction --endpoint /subscriptions/%subscription-id%/resourceGroups/%resource-group%/providers/Microsoft.Web/sites/%function-app-name%/functions/%function-name% %filter-parameter%)