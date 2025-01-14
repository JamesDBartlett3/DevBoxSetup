# Description: This script sets the Windows SMB client to allow insecure guest login on network shares.

# If running in PowerShell Core or not as Admin, switch to Admin Windows PowerShell
$isCore = $PSVersionTable.PSEdition -eq 'Core'
$isAdmin = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent().IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isCore -Or !$isAdmin) {
  Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
  Exit
}

Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force