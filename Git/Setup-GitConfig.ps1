# Check if running as admin. 
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# If not running as admin, warn user and ask if they want to restart as admin
if (-not $IsAdmin) {
	$restart = Read-Host "Some settings require administrator privileges to apply. Restart as administrator? (y/n)"
	if ($restart -ieq "y") {
		# Restart as admin using the same version of PowerShell that is currently running.
		$PSExePath = (Get-Process -Id $PID).path
		Start-Process "$PSExePath" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
	}
	exit
}

# System (Requires Admin)
if ($IsAdmin) {
	Write-Host "Applying 'git config --system' settings..."
	git config --system core.longpaths true
}
else {
	Write-Host "Administrator privileges not found. Skipping 'git config --system' settings..."
}

# Global
Write-Host "Applying 'git config --global' settings..."
git config --global core.autocrlf true
git config --global core.compression 0
git config --global core.editor "code --wait"
git config --global fetch.prune true

# Ask user if they want to apply settings from the .gitconfig file in this directory to the global .gitconfig file
$GitConfigFilePath = Join-Path -Path $PSScriptRoot -ChildPath ".gitconfig"
if (Test-Path -Path $GitConfigFilePath) {
	Write-Host "Found a .gitconfig file in this directory. Contents:"
	Write-Host "==============================================="
	Get-Content $GitConfigFilePath | Write-Host
	Write-Host "==============================================="
	$apply = Read-Host "Apply settings from this .gitconfig file to $env:USERNAME's .gitconfig? (y/n)"
	if ($apply -ieq "y") {
		Get-Content $GitConfigFilePath | Out-File -Append (Join-Path -Path $env:USERPROFILE -ChildPath ".gitconfig")
	}
}
