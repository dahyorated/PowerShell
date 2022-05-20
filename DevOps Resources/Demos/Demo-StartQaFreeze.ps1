Start-QaFreeze -UseTest -StartFreeze;
start microsoft-edge:https://eyglobaltaxplatform.visualstudio.com/Global%20Tax%20Platform/_queries/query/0d6403e9-f64a-4c1d-bf8b-a7b8c7bb451e/;
Read-Host "Press Enter after reviewing status";
Stop-QaFreeze -TestWorkItem;
