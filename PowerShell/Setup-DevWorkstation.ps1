<################################################################/

Setup-DevWorkstation.ps1

Usage:
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/JamesDBartlett3/DevBoxSetup/main/PowerShell/Setup-DevWorkstation.ps1'))"

Author: @JamesDBartlett3@techhub.social

TODO: Handle admin
TODO: Add call to Install-PSModules.ps1
TODO: Add option to overwrite local Microsoft.PowerShell_profile.ps1 with the one from this repo 
TODO: Install Chocolatey
TODO: Install Scoop

Based on this gist: https://gist.github.com/Codebytes/29bf18015f6e93fca9421df73c6e512c

/################################################################>

# Override locally cached copy of this script in case changes have been made since last run
[System.Net.ServicePointManager]::DnsRefreshTimeout = 0

#Install WinGet
$hasPackageManager = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'
if (!$hasPackageManager -or [version]$hasPackageManager.Version -lt [version]"1.10.0.0") {
  "Installing winget Dependencies"
  Add-AppxPackage -Path 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
  $releases_url = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $releases = Invoke-RestMethod -uri $releases_url
  $latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('msixbundle') } | Select-Object -First 1
  "Installing winget from $($latestRelease.browser_download_url)"
  Add-AppxPackage -Path $latestRelease.browser_download_url
}

#Configure WinGet
Write-Output "Configuring winget"

#winget config path from: https://github.com/microsoft/winget-cli/blob/master/doc/Settings.md#file-location
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
$settingsJson = 
@"
  {
    // For documentation on these settings, see: https://aka.ms/winget-settings
    "experimentalFeatures": {
      "experimentalMSStore": true,
    }
  }
"@
$settingsJson | Out-File $settingsPath -Encoding utf8

#Install New apps
Write-Output "Installing Apps"
$apps = @(
  @{name = "Chocolatey.ChocolateyGUI" },
  @{name = "Microsoft.Edge" },
  @{name = "Microsoft.AzureCLI" }, 
  @{name = "Microsoft.PowerShell" }, 
  @{name = "Microsoft.VisualStudioCode" }, 
  @{name = "Microsoft.WindowsTerminal" }, 
  @{name = "Microsoft.AzureStorageExplorer" }, 
  @{name = "Microsoft.PowerToys" }, 
  @{name = "Microsoft.PowerBI" },
  @{name = "Git.Git" },
  @{name = "Microsoft.DotNet.Runtime.7" },
  @{name = "Microsoft.DotNet.DesktopRuntime.7" },
  # @{name = "Microsoft.DotNet.Runtime.6" },
  # @{name = "Microsoft.DotNet.DesktopRuntime.6" },
  @{name = "Microsoft.DotNet.SDK.7" },
  # @{name = "Microsoft.DotNet.SDK.6" },
  @{name = "GitHub.cli" },
  @{name = "DaxStudio.DaxStudio" },
  # @{name = "GitHub.GitHubDesktop" },
  @{name = "Microsoft.Git" },
  @{name = "Microsoft.GitCredentialManagerCore" },
  @{name = "GitHub.GitLFS" },
  @{name = "JanDeDobbeleer.OhMyPosh" },
  # @{name = "winpython.winpython" },
  # @{name = "Canonical.Ubuntu" },
  # @{name = "beekeeper-studio.beekeeper-studio" },
  @{name = "gerardog.gsudo" },
  # @{name = "" },
  @{name = "Microsoft.AzureDataStudio" },
  @{name = "Microsoft.AzureDataCLI" },
  @{name = "Microsoft.AzureFunctionsCoreTools" },
  @{name = "Microsoft.AzureStorageEmulator" },
  @{name = "7zip.7zip" },
  # @{name = "voidtools.Everything" },
  @{name = "Sysinternals Suite"; source = "msstore"}, 
  @{name = "Microsoft PowerToys"; source = "msstore"}, # PowerToys
  @{name = "Microsoft.Sysinternals" }
)

winget list --accept-source-agreements | Out-Null;
Foreach ($app in $apps) {
  $listApp = winget list --exact -q $app.name
  if (![String]::Join("", $listApp).Contains($app.name)) {
    Write-Host "Installing:" $app.name
    if ($null -ne $app.source) {
      winget install --exact --silent $app.name --source $app.source
    }
    else {
      winget install --exact --silent $app.name 
    }
  }
  else {
    Write-Host "Skipping Install of " $app.name
  }
}

#Remove Apps
Write-Output "Removing Bloatware Apps..."

$apps = "*3DPrint*", "Microsoft.MixedReality.Portal", "*Xbox*", "Microsoft.Getstarted*"
Foreach ($app in $apps)
{
  Write-Host "Uninstalling:" $app
  Get-AppxPackage -allusers $app | Remove-AppxPackage
}

# Install Chocolatey
# apps: dotnet, dotnet-sdk, dotnetcore, dotnetcore-sdk

# Install Scoop
# apps: busybox, oh-my-posh, onecommander, winfetch

#Perform System Tweaks
Write-Output "Symlinking `e[38;2;0;255;0mMicrosoft.VSCode_profile.ps1`e[0m -> `e[38;2;0;255;0mMicrosoft.PowerShell_profile.ps1`e[0m..."
$profileDir = Split-Path $PROFILE
$vsCodeProfile = Join-Path $profileDir "Microsoft.VSCode_profile.ps1"
$psProfile = Join-Path $profileDir "Microsoft.PowerShell_profile.ps1"
New-Item -ItemType SymbolicLink -Path $vsCodeProfile -Target $psProfile