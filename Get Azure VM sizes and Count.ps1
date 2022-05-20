Connect-AzAccount
$AllVMs = (Get-AzVM).HardwareProfile.VmSize | Sort-Object -Unique
$AllVM = Get-AzVM
Write-Host Total number of VM:   $AllVM.count
Write-Host ""
foreach( $VM in $AllVMs){
$VMSize = Get-AZVM | Where-Object {$_.HardwareProfile.VMSize -eq $VM}
Write-Host Vitual Machine Size:    $VM
Write-Host Number of instances:  $VMSize.count
Write-Host ""
}