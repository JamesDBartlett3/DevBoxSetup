REM Windows Vista+
REG add "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_NotifyNewApps" /t REG_DWORD /d "0" /f >nul 2>&1 
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_NotifyNewApps" /t REG_DWORD /d "0" /f >nul 2>&1 

REM If Windows 8.x/10 add these lines too.
REG add "hklm\Software\Policies\Microsoft\Windows\Explorer" /v "HideRecentlyAddedApps" /t REG_DWORD /d "1" /f >nul 2>&1 
REG add "hklm\Software\Policies\Microsoft\Windows\Explorer" /v "NoNewAppAlert" /t REG_DWORD /d "1" /f >nul 2>&1 

REG add "hkcu\Software\Policies\Microsoft\Windows\Explorer" /v "HideRecentlyAddedApps" /t REG_DWORD /d "1" /f >nul 2>&1 
REG add "hkcu\Software\Policies\Microsoft\Windows\Explorer" /v "NoNewAppAlert" /t REG_DWORD /d "1" /f >nul 2>&1 

REG add "hkcu\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_NotifyNewApps" /t REG_DWORD /d "0" /f >nul 2>&1