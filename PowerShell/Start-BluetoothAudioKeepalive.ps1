<#

Plays a tone with x frequency (in Hz) for y miliseconds every z seconds
to prevent Bluetooth audio devices from auto-disconnecting due to inactivity.

For best results, choose a tone frequency above normal human hearing range (20,000+),
a length of about 1 second (1000 ms), and a delay just a bit shorter than your 
Bluetooth device's timeout length.

#>

Invoke-Command -ScriptBlock { 
    while($true) {
        [console]::beep(21800, 1000); Start-Sleep 300;
        } 
    }