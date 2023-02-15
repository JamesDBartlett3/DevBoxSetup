# View registry settings
# Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters FlipFlopWheel -EA 0
# Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters FlipFlopHScroll -EA 0

# Change registry settings
# Reverse mouse wheel scroll: 1 
# Normal mouse wheel scroll: 0 

# Get current PowerShell session process name
[string]$ps = (get-process -id $pid).ProcessName

# Check if script is running as administrator. If not, restart as administrator.
if(!!${env:=::}){Start-Process $ps "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit}

# Set registry settings
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters FlipFlopWheel -EA 0 | ForEach-Object { Set-ItemProperty $_.PSPath FlipFlopWheel 1 }
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters FlipFlopHScroll  -EA 0 | ForEach-Object { Set-ItemProperty $_.PSPath FlipFlopHScroll 1 }