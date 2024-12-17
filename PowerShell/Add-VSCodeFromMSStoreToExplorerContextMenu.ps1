$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
$VSCodePath = "C:\Users\$UserName\AppData\Local\Programs\Microsoft VS Code\Code.exe"

# Open files
New-Item -Path "HKCU:\Software\Classes\*\shell\Open with VS Code" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\Open with VS Code" -Name "(default)" -Value "Edit with VS Code"
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\Open with VS Code" -Name "Icon" -Value "$VSCodePath,0"
New-Item -Path "HKCU:\Software\Classes\*\shell\Open with VS Code\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\*\shell\Open with VS Code\command" -Name "(default)" -Value "`"$VSCodePath`" `"%1`""

# This will make it appear when you right click ON a folder
New-Item -Path "HKCU:\Software\Classes\Directory\shell\vscode" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\vscode" -Name "(default)" -Value "Open Folder as VS Code Project"
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\vscode" -Name "Icon" -Value "`"$VSCodePath`",0"
New-Item -Path "HKCU:\Software\Classes\Directory\shell\vscode\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\vscode\command" -Name "(default)" -Value "`"$VSCodePath`" `"%1`""

# This will make it appear when you right click INSIDE a folder
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode" -Name "(default)" -Value "Open Folder as VS Code Project"
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode" -Name "Icon" -Value "`"$VSCodePath`",0"
New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\vscode\command" -Name "(default)" -Value "`"$VSCodePath`" `"%V`""