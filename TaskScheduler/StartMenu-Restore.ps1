# StartMenu-Restore.ps1
# Restores start2.bin from a backup. Run as needed when pins get wiped.
#
# Usage:
#   .\StartMenu-Restore.ps1 "C:\path\to\backup\start2_2026-06-20_01-45-00.bin"
#   .\StartMenu-Restore.ps1               # Opens file picker if no path given

param(
    [string]$BackupFile
)

$target = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
$backupRoot = "$env:USERPROFILE\Documents\StartMenuBackups"

if (-not $BackupFile) {
    # No argument passed — show file picker
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select start2.bin backup to restore"
    $dialog.InitialDirectory = $backupRoot
    $dialog.Filter = "Start Menu Backup (*.bin)|*.bin|All Files (*.*)|*.*"
    if ($dialog.ShowDialog() -ne "OK") {
        Write-Output "Cancelled."
        exit 0
    }
    $BackupFile = $dialog.FileName
}

if (-not (Test-Path $BackupFile)) {
    Write-Error "Backup file not found: $BackupFile"
    exit 1
}

Write-Output "Killing StartMenuExperienceHost..."
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Output "Restoring start2.bin from: $BackupFile"
Copy-Item $BackupFile $target -Force

Write-Output "Restarting StartMenuExperienceHost..."
Start-Process StartMenuExperienceHost

Write-Output ""
Write-Output "Done! Sign out and back in (or restart Explorer) to see your pinned items."
