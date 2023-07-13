<##########################################################################/

Author: @JamesDBartlett3@techhub.social

Infinite loop that plays a tone with x frequency (in Hz) for y miliseconds 
to prevent audio devices from sleeping due to inactivity.

For best results, choose a tone frequency above normal human hearing range 
(20,000+ Hz) and a length of several hours.

/##########################################################################>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)][Int64]$FrequencyInHz = 21800,
    [Parameter(Mandatory = $false)][Int64]$LengthInMs = 10800000
)

Invoke-Command -ScriptBlock {
    while($true) {
        [console]::beep($FrequencyInHz, $LengthInMs)
    }
}