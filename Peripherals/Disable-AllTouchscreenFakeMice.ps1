<#
.SYNOPSIS
    Disables the "fake mouse" HID devices created by touchscreens.

.DESCRIPTION
    Some touchscreens expose a companion "Mouse" class device alongside their real
    "HID-compliant touch screen" digitizer, which can cause unwanted cursor jumps/clicks,
    touch events being interpreted as mouse events, touch events being routed to the wrong
    display, and other issues. 

    This script finds all PnP devices, groups them by their parent device, and for any
    parent that has both an 'HID-compliant touch screen' sibling and a 'Mouse' class
    sibling, it disables the 'Mouse' class device, then disables and re-enables the
    touch screen device to force it to re-register without recreating the fake mouse.

    The script requires administrator privileges and will self-elevate if needed.

.EXAMPLE
    .\Disable-AllTouchscreenFakeMice.ps1
    Disables all fake mouse devices associated with touchscreens on the system.
#>

# If not running as Admin, relaunch elevated
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Start-Process (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

$children = Get-PnpDevice | ForEach-Object {
    $parent = (
        Get-PnpDeviceProperty `
            -InstanceId $_.InstanceId `
            -KeyName 'DEVPKEY_Device_Parent' `
            -ErrorAction SilentlyContinue
    ).Data

    if ($parent) {
        [pscustomobject]@{
            Device = $_
            Parent = $parent
        }
    }
}

$children |
    Group-Object Parent |
    Where-Object {
        $_.Group.Device.FriendlyName -contains 'HID-compliant touch screen' -and
        $_.Group.Device.Class -contains 'Mouse'
    } |
    ForEach-Object {
        $_.Group.Device |
            Where-Object Class -eq 'Mouse' |
            Disable-PnpDevice -Confirm:$false

        # Cycling the touch screen device forces it to re-register without recreating the fake mouse
        $touchScreen = $_.Group.Device | Where-Object FriendlyName -eq 'HID-compliant touch screen'
        $touchScreen | Disable-PnpDevice -Confirm:$false
        $touchScreen | Enable-PnpDevice -Confirm:$false
    }