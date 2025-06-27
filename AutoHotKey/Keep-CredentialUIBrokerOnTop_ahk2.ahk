#Requires AutoHotkey v2.0
Persistent
SetTimer(KeepOnTop, 1000)  ; Check every 1 second

KeepOnTop(*) {
  hwnd := WinExist("ahk_exe CredentialUIBroker.exe")
  if hwnd {
    WinActivate("ahk_id " hwnd)               ; Bring to foreground
    WinSetAlwaysOnTop(true, "ahk_id " hwnd)   ; Set always on top
  }
}