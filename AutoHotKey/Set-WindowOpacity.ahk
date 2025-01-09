TLevel = 180

#^Esc::
    WinGet, CurrentTLevel, Transparent, A
    If (CurrentTLevel = OFF) {
        WinSet, Transparent, %TLevel%, A
    } Else {
        WinSet, Transparent, OFF, A
    }
return

 SetTransparency:
    WinGet, CurrentTLevel, Transparent, A
    WinSet, Transparent, %TLevel%, A
return

#^=::
    TLevel += 10
    If TLevel >= 255
    {
        TLevel = 255
    }
    
    Gosub, SetTransparency
return

#^-::
    TLevel -= 10
    If TLevel <= 0
    {
        TLevel = 0
    }
    
    Gosub, SetTransparency
return