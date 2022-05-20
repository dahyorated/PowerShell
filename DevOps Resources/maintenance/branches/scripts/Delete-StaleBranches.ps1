param(
    [Parameter(Mandatory=$False)]
    [string]$csv="C:\Users\ZT354YY\Downloads\BranchesToBeDeletedFinal.csv"
)
$stalebranch= import-csv $csv;
#Set the loation of the repo
Set-Location "C:\GTP\Global Tax Platform"
#loop throgh each row
foreach ($stale in $stalebranch) {
#delete branches found under header branch
git push origin --delete $stale.branch
}
