[[_TOC_]]

# TenantSubscriptions
This folder contains files needed for Creation of RSG pipeline

Created a pipeline called "CreateDefaultRSGTenant-Subscriptions" . It is saved under All Pipelines>DevOps>TenantPipelines.

Pipeline uses a script CreateDefaultRSG.ps1 which is located in  devops/TenantSubscriptions to import information from csv file and created RSG using that information

It uses a file "$PSScriptRoot\RSGInfoSheet.csv" which contains information on what subscriptions need what RSGs created.
"$PSScriptRoot\PayloadTemplate.txt" – is used as payload template file for specifying parameters. 

If make any updates to script or csv file, you need to manually run DevOps-CI pipeline to put those changes in an artifact that can be used for deploying the release pipeline to create RSG
 
