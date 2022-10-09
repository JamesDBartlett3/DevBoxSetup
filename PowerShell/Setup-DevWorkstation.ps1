<################################################################/

Setup-DevWorkstation.ps1

Usage:
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/JamesDBartlett3/PoshBits/main/Setup-DevWorkstation.ps1'))"

Author: @JamesDBartlett3

TODO: Handle admin
TODO: Add call to Install_PowerShell_Modules.ps1

/################################################################>

#Install WinGet
#Based on this gist: https://gist.github.com/Codebytes/29bf18015f6e93fca9421df73c6e512c
$hasPackageManager = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'
if (!$hasPackageManager -or [version]$hasPackageManager.Version -lt [version]"1.10.0.0") {
    "Installing winget Dependencies"
    Add-AppxPackage -Path 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'

    $releases_url = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $releases = Invoke-RestMethod -uri $releases_url
    $latestRelease = $releases.assets | Where { $_.browser_download_url.EndsWith('msixbundle') } | Select -First 1

    "Installing winget from $($latestRelease.browser_download_url)"
    Add-AppxPackage -Path $latestRelease.browser_download_url
}
else {
    "winget already installed"
}

#Configure WinGet
Write-Output "Configuring winget"

#winget config path from: https://github.com/microsoft/winget-cli/blob/master/doc/Settings.md#file-location
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json";
$settingsJson = 
@"
    {
        // For documentation on these settings, see: https://aka.ms/winget-settings
        "experimentalFeatures": {
          "experimentalMSStore": true,
        }
    }
"@;
$settingsJson | Out-File $settingsPath -Encoding utf8

#Install New apps
Write-Output "Installing Apps"
$apps = @(
    @{name = "Microsoft.AzureCLI" }, 
    @{name = "Microsoft.PowerShell" }, 
    @{name = "Microsoft.VisualStudioCode" }, 
    @{name = "Microsoft.WindowsTerminal" }, 
    @{name = "Microsoft.AzureStorageExplorer" }, 
    @{name = "Microsoft.PowerToys" }, 
    @{name = "Microsoft.PowerBI" },
    @{name = "Git.Git" }, 
    # @{name = "Docker.DockerDesktop" },
    @{name = "Microsoft.dotnet" },
    @{name = "GitHub.cli" },
    @{name = "DaxStudio.DaxStudio" },
    @{name = "GitHub.GitHubDesktop" },
    @{name = "Microsoft.GitCredentialManagerCore" },
    # @{name = "Microsoft.Git" },
    @{name = "GitHub.GitLFS" },
    @{name = "JanDeDobbeleer.OhMyPosh" },
    @{name = "winpython.winpython" },
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
    # @{name = "9P7KNL5RWT25"; source = "msstore"}, # alternate source for Sysinternals Suite
    # @{name = "SamHocevar.WinCompose" }
    @{name = "Microsoft.Sysinternals" }
);
winget list --accept-source-agreements | Out-Null;
Foreach ($app in $apps) {
    $listApp = winget list --exact -q $app.name
    if (![String]::Join("", $listApp).Contains($app.name)) {
        Write-host "Installing:" $app.name
        if ($app.source -ne $null) {
            winget install --exact --silent $app.name --source $app.source
        }
        else {
            winget install --exact --silent $app.name 
        }
    }
    else {
        Write-host "Skipping Install of " $app.name
    }
}

#Remove Apps
Write-Output "Removing Apps"

$apps = "*3DPrint*", "Microsoft.MixedReality.Portal"
Foreach ($app in $apps)
{
  Write-host "Uninstalling:" $app
  Get-AppxPackage -allusers $app | Remove-AppxPackage
}
