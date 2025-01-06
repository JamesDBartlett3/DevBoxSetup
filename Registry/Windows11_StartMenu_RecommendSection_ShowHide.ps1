# Check Windows version. If less than 11, inform user and exit.
if ([System.Environment]::OSVersion.Version.Build -lt 22000 -or [System.Environment]::OSVersion.Version.Major -gt 10) {
  Write-Host "This script is only for Windows 11. Exiting..."
  exit
}

# Get current PowerShell session process name
[string]$ps = (get-process -id $pid).ProcessName

# Check if script is running as administrator. If not, restart as administrator.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
	[Security.Principal.WindowsBuiltInRole] "Administrator")) { `
	Start-Process $ps "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
	-Verb RunAs; exit }

# Let user choose to show or hide the Recommended section from the Start menu (1 = hide, 0 = show)
$hideRecommendedSection = Read-Host "Hide 'Recommended' section from Start menu? (1 = hide, 0 = show)"

New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -PropertyType DWord -Value $hideRecommendedSection -Force