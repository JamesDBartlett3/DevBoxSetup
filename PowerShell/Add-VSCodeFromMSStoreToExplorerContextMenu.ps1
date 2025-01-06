# If not running as admin, restart as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
	# Restart as admin using the same version of PowerShell that is currently running.
	$PSExePath = (Get-Process -Id $PID).Path
	Start-Process "$PSExePath" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
	exit
}

# Get the current user's name and the path to VS Code
$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
$VSCodePath = "C:\Users\$UserName\AppData\Local\Programs\Microsoft VS Code\Code.exe"

# Test to make sure VS Code is installed
if (-not (Test-Path $VSCodePath)) {
	Write-Host "VS Code is not installed at $VSCodePath. Please install it from the Microsoft Store and try again."
	exit
}

# This will make it appear when you right click on a file
Write-Host -NoNewline "Adding 'Open with VS Code' to the context menu for files... "
New-Item -Path "HKCU:\Software\Classes\*\shell\Open with VS Code" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\Open with VS Code" -Name "(default)" -Value "Edit with VS Code"
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\Open with VS Code" -Name "Icon" -Value "$VSCodePath,0"
New-Item -Path "HKCU:\Software\Classes\*\shell\Open with VS Code\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\Open with VS Code\command" -Name "(default)" -Value "`"$VSCodePath`" `"%1`""
Write-Host "Done."

# This will make it appear when you right click ON a folder
Write-Host -NoNewline "Adding 'Open Folder as VS Code Project' to the context menu that appears when the user right-clicks ON a folder... "
New-Item -Path "HKCU:\Software\Classes\Directory\shell\vscode" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\vscode" -Name "(default)" -Value "Open Folder as VS Code Project"
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\vscode" -Name "Icon" -Value "`"$VSCodePath`",0"
New-Item -Path "HKCU:\Software\Classes\Directory\shell\vscode\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\vscode\command" -Name "(default)" -Value "`"$VSCodePath`" `"%1`""
Write-Host "Done."

# This will make it appear when you right click INSIDE a folder
Write-Host -NoNewline "Adding 'Open Folder as VS Code Project' to the context menu that appears when the user right-clicks INSIDE a folder... "
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode" -Name "(default)" -Value "Open Folder as VS Code Project"
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode" -Name "Icon" -Value "`"$VSCodePath`",0"
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode\command" -Name "(default)" -Value "`"$VSCodePath`" `"%V`""
Write-Host "Done."