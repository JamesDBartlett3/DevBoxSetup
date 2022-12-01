$ps = (get-process -id $pid).ProcessName
if(!!${env:=::}){Start-Process $ps "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit}
slmgr –rearm
slmgr -ato
Write-Output "Windows Evaluation License has been reset. Change will take effect after next reboot. Press any key to continue..."
[Console]::ReadKey() | Out-Null
