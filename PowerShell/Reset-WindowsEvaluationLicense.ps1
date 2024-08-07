<################################################################/

  Title: Reset-WindowsEvaluationLicense.ps1
  Author: @JamesDBartlett3@techhub.social
  
  Synopsis: Resets the Windows Evaluation License expiration to 
  90 days from the current date.

  Usage: .\Reset-WindowsEvaluationLicense.ps1

  DISCLAIMER: This script is provided for developer testing
  purposes only. It is not intended for use in a production
  environment, and should not be used for any purpose other
  than testing. The author is not responsible for any damage,
  data loss, legal liability, or any other consequences that 
  may result from the use of this script. By using this script,
  you agree to these terms.

/################################################################>

# Get current PowerShell session process name
[string]$ps = (get-process -id $pid).ProcessName

# Check if script is running as administrator. If not, restart as administrator.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
	[Security.Principal.WindowsBuiltInRole] "Administrator")) { `
	Start-Process $ps "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
	-Verb RunAs; exit }

# Invoke slmgr to reset evaluation license
"slmgr -rearm; slmgr -ato" | Invoke-Expression

# Display message and ask if user would like to reboot now
$reboot = Read-Host "Windows Evaluation License has been reset. Change will take effect after next reboot. Would you like to reboot now? (Y/N)"
if($reboot -eq "Y") {
  Write-Host "Rebooting in 5 seconds..."
  Start-Sleep -Seconds 5
  Restart-Computer -Force
} else {
  Write-Host "Reboot later to complete the process."
}

# Optionally disable the WLMS service to prevent automatic shutdown every hour
$disableWLMS = Read-Host "Would you like to disable the WLMS service to prevent automatic shutdown every hour? (Y/N)"
if($disableWLMS.ToUpper() -eq "Y") {
	
	# Check if PsExec is installed. If not, download and extract it.
	$psexecPath = (Get-Command psexec -ErrorAction SilentlyContinue).Source
	if(!$psexecPath) {
		Invoke-WebRequest "https://download.sysinternals.com/files/PSTools.zip" -OutFile "$env:TEMP\PSTools.zip"
		Expand-Archive -Path "$env:TEMP\PSTools.zip" -DestinationPath "$env:TEMP\PSTools"
		$psexecPath = "$env:TEMP\PSTools\PsExec.exe"
	}
	
	# Disable WLMS service
	Invoke-Expression -Command "$psexecPath -i -s $ps -c 'Set-Service -Name wlms -StartupType Disabled'"
	
	# Ask the user to reboot to complete the process
	$reboot = Read-Host "Reboot is required to complete the process. Would you like to reboot now? (Y/N)"
	if($reboot.ToUpper() -eq "Y") {
		Write-Host "Rebooting in 5 seconds..."
		Start-Sleep -Seconds 5
		Restart-Computer -Force
	} else {
		Write-Host "Reboot later to complete the process."
	}
	
} else {
	Write-Host "WLMS service has not been disabled."
}


