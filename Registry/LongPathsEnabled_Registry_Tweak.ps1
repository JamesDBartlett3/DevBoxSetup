# Get current PowerShell session process name
[string]$ps = (get-process -id $pid).ProcessName

# Check if script is running as administrator. If not, restart as administrator.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
	[Security.Principal.WindowsBuiltInRole] "Administrator")) { `
	Start-Process $ps "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
	-Verb RunAs; exit }

# Enable long paths
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force