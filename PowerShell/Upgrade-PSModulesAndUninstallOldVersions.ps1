<################################################################/

Upgrade-PSModulesAndUninstallOldVersions.ps1

This script will upgrade all installed PowerShell modules. 
After installing a new version of a module, it will uninstall 
the old version(s).

Usage: 
pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/JamesDBartlett3/DeBoxSetup/main/PowerShell/Upgrade-PSModulesAndUninstallOldVersions.ps1'))"

Author: @JamesDBartlett3@techhub.social

TODO: Refactor using this example: https://github.com/itpro-tips/PowerShell-Toolbox/blob/master/Update-AllPowerShellModules.ps1

/################################################################>

#Requires -Modules PSScriptTools

# Set DNS refresh timeout to 0 to prevent DNS caching issues
[System.Net.ServicePointManager]::DnsRefreshTimeout = 0

Function Add-Separator {
    Param(
        [Parameter(Mandatory=$false)]
        [int]$Width = $Host.UI.RawUI.WindowSize.Width
    )
    Write-Host ('-' * $Width)
}

Add-Separator

Write-Host "Checking installed modules for available updates and/or old version(s) to uninstall..." `
  -ForegroundColor Blue -BackgroundColor Black

Add-Separator

# Get all installed modules for which an update is available
$mods = Get-InstalledModule | Compare-Module |
  Where-Object {$_.InstalledVersion -ne $_.OnlineVersion}

# For each module
foreach ($m in $mods) {

  $name = $m.Name

  # If the module has an update available, install it
  if ($m.UpdateNeeded) {
    Write-Host "Updating '$name' module..." `
      -ForegroundColor Yellow -BackgroundColor Black
    Update-Module -Name $name -AcceptLicense
  }

  # Get list of all currently installed versions of the module, sorted by Published Date
  $installedVersions = Get-InstalledModule -Name $name -AllVersions |
    Sort-Object -Property PublishedDate

  # If more than one version is installed...
  if ($installedVersions.Count -gt 1) { #TODO: This condition most likely never returns false, so it is probably unnecessary

    # Get total number of versions installed and the version number of the latest version
    $oldVersionsCount = $installedVersions.Count - 1
    $oldVersions = $installedVersions | Select-Object -First $oldVersionsCount
    $latestVersion = $installedVersions[-1].Version
    Write-Host "Latest version of '$name' module (version $latestVersion) is now installed." `
      -ForegroundColor Green -BackgroundColor Black

    # Uninstall each old version
    foreach ($v in $oldVersions) {

      $name = $v.Name
      $version = $v.Version
      Write-Host "Uninstalling outdated version of '$name' module (version $version)..." `
        -ForegroundColor Red -BackgroundColor Black
      Uninstall-Module $v -Force

    }

    Add-Separator

  }

}

Write-Host "Finished updating modules and uninstalling old versions." `
  -ForegroundColor Blue -BackgroundColor Black
