# Bash-like tab completion & command history
# Source: https://www.rasmusolsson.dev/posts/powershell-autocomplete
  ## Imports PSReadLine
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
  
# Other Stuff:
