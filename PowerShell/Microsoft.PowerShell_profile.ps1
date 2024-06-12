# Bash-like tab completion & command history
# Original Source: https://www.rasmusolsson.dev/posts/powershell-autocomplete

# PSReadLine Mods
## Import PSReadLine
# Import-Module PSReadLine
## Tab - Gives a menu of suggestions
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
## UpArrow will show the most recent command
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
## DownArrow will show the least recent command
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
## During auto completion, pressing arrow key up or down will move the cursor to the end of the completion
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
## Shows tooltip during completion
Set-PSReadLineOption -ShowToolTips
## Gives completions/suggestions from historical commands
Set-PSReadLineOption -PredictionSource History

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
	Import-Module "$ChocolateyProfile"
}

# PowerShell Prompt Mods & Themes
## Enable git repo status awareness with Posh-Git
Import-Module posh-git
## Enable PowerShell prompt theming with Oh-My-Posh
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\froczh.omp.json" | Invoke-Expression

# Enable 'sudo' command in PowerShell
Import-Module 'gsudoModule'

# Enable WinGetCommandNotFound feature (from Microsoft PowerToys)
$CommandNotFoundModulePath = (Get-ChildItem -Path ~\Documents\PowerShell\Modules\Microsoft.WinGet.CommandNotFound -Filter *.psd1 -Recurse)[-1].FullName
Import-Module $CommandNotFoundModulePath

# Define a function to update all packages installed via Scoop, Chocolatey, and WinGet
function Update-AllPackages {
	sudo {
		choco upgrade all --yes --limit-output;
		winget upgrade --all --accept-package-agreements;
	}
	scoop update *
}
New-Alias -Name "Upgrade-AllPackages" -Value Update-AllPackages