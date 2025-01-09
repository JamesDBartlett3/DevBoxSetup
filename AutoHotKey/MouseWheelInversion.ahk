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