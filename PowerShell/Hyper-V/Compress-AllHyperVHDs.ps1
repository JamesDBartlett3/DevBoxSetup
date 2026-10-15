#=================================================================================
#  Compact VHDX space consumed on disk
#
#  Author: Kevin Holman
#  v1.0
#=================================================================================
Clear-Host

#Get All VMs that are off
Write-Host "`nGetting all Virtual Machines on Host that are powered off..."
$VMs = Get-VM | Where-Object { $_.State -eq "Off" }

#Example - Get a specific VM for testing
#$VMs = Get-VM | Where {$_.Name -eq "DC1"}
#Example - Get specific VMs matching a name wildcard for testing
#$VMs = Get-VM | Where {$_.Name -like "SQL*" -and $_.State -eq "Off"}

#Get total disk space consumed by all VM disks
Write-Host "`nGetting all Disks and calculating their total space consumed on disk before compacting..."
$Disks = $VMs | Select-Object VMid | Get-VHD
[double]$DisksTotalSize = 0
[double]$DisksTotalSizeGBbefore = 0
FOREACH ($Disk in $Disks) {
	$DisksTotalSize = $DisksTotalSize + $Disk.FileSize
}
$DisksTotalSizeGBbefore = [math]::round($DisksTotalSize / 1GB, 2)
Write-Host "`nThe total space consumed on disk by VMs before compacting is ($DisksTotalSizeGBbefore) GB"

#Begin Compaction
Write-Host "`nBeginning compaction.  This can take a long time..."
FOREACH ($VM in $VMs) {
	Write-Host `n"Getting Disks for $($VM.Name)"
	$VMDisks = $VM.HardDrives
	FOREACH ($VMDisk in $VMDisks) {
		$VMDiskPath = $VMDisk.Path
		Write-Host "Found VHDX at ($VMDiskPath)"
		#Mount the VHDX
		Write-Host "Mounting VHDX"
		$Error.Clear()
		Mount-VHD -Path $VMDiskPath -ReadOnly
		IF (!($Error)) {
			Write-Host "Pass 1: Optimizing VHDX at ($VMDiskPath)"
			Optimize-VHD -Path $VMDiskPath -Mode Full -ErrorAction Continue
			Write-Host "Pass 2: Optimizing VHDX at ($VMDiskPath)"
			Optimize-VHD -Path $VMDiskPath -Mode Full -ErrorAction Continue
		}
		Write-Host "Dismounting VHDX"
		Dismount-VHD -Path $VMDiskPath
	}
}

#Get total disk space consumed by all VM disks
Write-Host "`nGetting all Disks and calculating their total space consumed on disk after compacting..."
$Disks = $VMs | Select-Object VMid | Get-VHD
[double]$DisksTotalSize = 0
[double]$DisksTotalSizeGBafter = 0
FOREACH ($Disk in $Disks) {
	$DisksTotalSize = $DisksTotalSize + $Disk.FileSize
}
$DisksTotalSizeGBafter = [math]::round($DisksTotalSize / 1GB, 2)
Write-Host "`nThe total space consumed on disk by VMs before compacting is ($DisksTotalSizeGBbefore) GB"
Write-Host "`nThe total space consumed on disk by VMs after compacting is ($DisksTotalSizeGBafter) GB"
$DiskSpaceFreed = ($DisksTotalSizeGBbefore - $DisksTotalSizeGBafter)
Write-Host "`nThe total space free on disk by compacting VMs is ($DiskSpaceFreed) GB"