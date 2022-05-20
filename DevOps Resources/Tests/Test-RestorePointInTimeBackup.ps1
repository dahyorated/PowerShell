$rg = 'GT-WEU-GTP-TENANT-DEMO-RSG'
$db = 'euwegtp035sql03'
$cid = @(2,5,6,7)
$sn = 'EY-CTSBP-PROD-TAX-GTP_DEMO_TENANT-01-39861197'
Restore-PointInTimeBackup -Subscription $sn -GroupName $rg -Server $db -ClientIds $cid;
