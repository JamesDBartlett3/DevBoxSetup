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
## Shows tooltip during completion
Set-PSReadLineOption -ShowToolTips
## Gives completions/suggestions from historical commands
Set-PSReadLineOption -PredictionSource History


# PowerShell Prompt Mods & Themes
## Enable git repo status awareness with Posh-Git
Import-Module posh-git
## Enable PowerShell prompt theming with Oh-My-Posh
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\froczh.omp.json" | Invoke-Expression