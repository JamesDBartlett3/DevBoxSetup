#region PSReadLine

# Bash-like tab completion & command history
# Original Source: https://www.rasmusolsson.dev/posts/powershell-autocomplete

# PSReadLine Mods
## Import PSReadLine
Import-Module PSReadLine
## Tab - Gives a menu of suggestions
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
## UpArrow will show the most recent command
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
## DownArrow will show the least recent command
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
## During auto completion, pressing arrow key up or down will move the cursor to the end of the completion
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
## Show a list of suggestions during completion, instead of inline
Set-PSReadLineOption -PredictionViewStyle ListView
## Shows tooltip during completion
Set-PSReadLineOption -ShowToolTips
## Gives completions/suggestions from historical commands
Set-PSReadLineOption -PredictionSource History
## Enable Ctrl+Space to trigger MenuComplete completion
Set-PSReadLineKeyHandler -Function MenuComplete -Chord 'Ctrl+@'

#endregion


# DEPRECATED: This section is no longer necessary, as UniGetUI has replaced the need for it.
# # Import the Chocolatey Profile that contains the necessary code to enable
# # tab-completions to function for `choco`.
# # Be aware that if you are missing these lines from your profile, tab completion
# # for `choco` will not function.
# # See https://ch0.co/tab-completion for details.
# $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
# if (Test-Path($ChocolateyProfile)) {
#   Import-Module "$ChocolateyProfile"
# }

# DEPRECATED: This function is no longer necessary, as UniGetUI has replaced the need for it. 
# # Define a function to update all packages installed via Scoop, Chocolatey, and WinGet
# function Update-AllPackages {
#   gsudo {
#     choco upgrade all --yes --limit-output;
#     winget upgrade --all --accept-package-agreements;
#   }
#   scoop update *
# }
# New-Alias -Name "Upgrade-AllPackages" -Value Update-AllPackages

#region General

## Enable WinGetCommandNotFound feature (from Microsoft PowerToys)
try {
  Import-Module Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
}
catch {
  $CommandNotFoundModuleFolder = "~\Documents\PowerShell\Modules\Microsoft.WinGet.CommandNotFound"
  if (Test-Path $CommandNotFoundModuleFolder) {
    # Find the latest installed version of the CommandNotFound module
    $CommandNotFoundModule = (Get-ChildItem -Path $CommandNotFoundModuleFolder -Filter *.psd1 -Recurse)[-1].FullName
    Import-Module $CommandNotFoundModule
  }
}

## Override the default 'touch' command
function touch {
  # Params for passthrough to real touch.exe
  param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$Paths
  )
  Remove-Item Function:touch -ErrorAction SilentlyContinue
  & touch.exe @Paths
}

# DEPRECATED: This module is no longer necessary, as oh-my-posh has replaced the need for it.
# ## Enable git repo status awareness with Posh-Git
# Import-Module posh-git

## Enable 'sudo' command in PowerShell
Import-Module 'gsudoModule'

#endregion


#region ChrisTitus Overrides

## Set the oh-my-posh theme
$themeName = "craver"
$localThemePath = "$env:POSH_THEMES_PATH\$themeName.omp.json"
function Get-Theme_Override {
  # Look for theme locally first, then fallback to the online version if not found
  if (Test-Path $localThemePath) {
    Write-Debug "Loading local theme from $localThemePath"
    oh-my-posh.exe init pwsh --config $localThemePath | Invoke-Expression
    return
  }
  Write-Warning "Local theme not found; loading from online source. Consider downloading the theme and placing it in $env:POSH_THEMES_PATH for faster loading and offline availability."
  oh-my-posh.exe init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$themeName.omp.json | Invoke-Expression
}

## Monkey-patch Write-Host to silence the 'Show-Help' message
$global:OriginalWriteHost = Get-Command Write-Host
function Write-Host {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0, ValueFromRemainingArguments=$true)]
        [System.Object]$Object,
        [Switch]$NoNewline,
        [System.Object]$Separator,
        [System.ConsoleColor]$ForegroundColor,
        [System.ConsoleColor]$BackgroundColor
    )
    process {
        if (([string]$Object) -match "Use 'Show-Help' to display help") {
            return
        }
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
    }
}

#endregion