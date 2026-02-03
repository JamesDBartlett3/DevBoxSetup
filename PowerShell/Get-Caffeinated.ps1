<#
.SYNOPSIS
    Simulates periodic user activity to keep the system awake.

.DESCRIPTION
    Sends periodic key presses to prevent the system from sleeping or locking.
    This script runs in an infinite loop and is useful for keeping a system
    active during long operations or presentations.

.PARAMETER Key
    The key to press. Default is "F16".
    - Single character: A, B, 1, or " " (space)
    - Named key: Space, UP, DOWN, F16 (auto-wrapped to {SPACE}, {UP}, etc.)
    - Already wrapped: {ENTER}, {UP} (passed as-is)
    - With modifiers: ^A (Ctrl+A), +{UP} (Shift+Up), %{F4} (Alt+F4)

.PARAMETER Delay
    The delay in seconds between key presses. Default is 60. Must be at least 1.

.EXAMPLE
    .\Get-Caffeinated.ps1
    Presses F16 every 60 seconds (default behavior).

.EXAMPLE
    .\Get-Caffeinated.ps1 -Key UP -Delay 120
    Presses the Up arrow key every 2 minutes.

.EXAMPLE
    .\Get-Caffeinated.ps1 -Key " " -Delay 30
    Presses spacebar every 30 seconds.

.NOTES
    - Press Ctrl+C to stop the script
    - This script requires the System.Windows.Forms assembly
    - Some applications may block certain key presses
#>

param(
    [string]$Key = "F16",
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Delay = 60
)

# Validate key parameter
if ([string]::IsNullOrWhiteSpace($Key)) {
    throw "Key parameter cannot be empty."
}

Add-Type -AssemblyName System.Windows.Forms

# Wrap special key names in braces if not already wrapped
# Don't wrap if:
# - Already wrapped in braces
# - Single character (including space)
# - Starts with modifier prefix (^, +, %)
if ($Key -notmatch '^\{.*\}$' -and 
    $Key.Length -gt 1 -and 
    $Key -notmatch '^[\^+%]') {
    $Key = "{$Key}"
}

Write-Host "Keeping system awake by pressing '$Key' every $Delay seconds. Press Ctrl+C to stop." -ForegroundColor Green

while ($true) {
    [System.Windows.Forms.SendKeys]::SendWait($Key) | Out-Null
    Start-Sleep -Seconds $Delay
}