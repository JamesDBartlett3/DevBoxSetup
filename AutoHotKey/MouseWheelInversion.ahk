; Intercept and invert all mouse scroll events (i.e., scroll down instead of up, left instead of right, etc.)

#NoTrayIcon

WheelUp::
Send {WheelDown}
Return

WheelDown::
Send {WheelUp}
Return

WheelLeft::
Send {WheelRight}
Return

WheelRight::
Send {WheelLeft}
Return


WM_WTSSESSION_CHANGE(wParam, lParam, Msg, hWnd){
	static init:=(DllCall( "Wtsapi32.dll\WTSRegisterSessionNotification", UInt, A_ScriptHwnd, UInt, 1) && OnMessage(0x02B1, "WM_WTSSESSION_CHANGE"))
	,_:={base:{__Delete: "WM_WTSSESSION_CHANGE"}}
	
	if !(_)
		DllCall("Wtsapi32.dll\WTSUnRegisterSessionNotification", "UInt", hWnd)
	
	/*
	wParam_1 = WTS_CONSOLE_CONNECT
	wParam_2 = WTS_CONSOLE_DISCONNECT
	wParam_3 = WTS_REMOTE_CONNECT
	wParam_4 = WTS_REMOTE_DISCONNECT
	wParam_5 = WTS_SESSION_LOGON
	wParam_6 = WTS_SESSION_LOGOFF
	wParam_7 = WTS_SESSION_LOCK
	wParam_8 = WTS_SESSION_UNLOCK
	wParam_9 = WTS_SESSION_REMOTE_CONTROL
	*/
	
	If (wParam=0x5 || wParam=0x8) ;Logon or unlock
		SetTimer,Rehook,-3000 ;Reapply hook after xx milliseconds. Use -xx to run only once.
	Return
	
	Rehook:
		Suspend,On
		Suspend,Off
	Return
}