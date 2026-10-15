# Simulate keypress of Ctrl + Alt + Break
$wsh = New-Object -ComObject WScript.Shell
$wsh.SendKeys('^%{BREAK}')
