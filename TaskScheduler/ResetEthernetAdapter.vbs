' This script resets all Ethernet adapters that are either up or not connected.
' It disables and then re-enables them to reset their state.
Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -Command ""Get-NetAdapter | Where-Object { ($_.Status -eq 'Up' -or $_.MediaConnectionState -ne 'Connected') -and $_.Name -like '*Ethernet*' } | ForEach-Object { Disable-NetAdapter $_.Name -Confirm:$false; Start-Sleep 5; Enable-NetAdapter $_.Name }""", 0, False