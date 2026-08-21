#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()][string]$PrimaryMicId,
    [Parameter()][string]$SecondaryMicId,
    [Parameter()][string]$Hotkey = 'Ctrl+Alt+M',
    [Parameter()][switch]$SelectMicDevices,
    [Parameter()][string]$ConfigPath,
    [Parameter()][string]$SaveConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-JsonConfiguration {
    param(
        [Parameter()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [ordered]@{
            PrimaryMicId = $null
            SecondaryMicId = $null
            Hotkey = 'Ctrl+Alt+M'
        }
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $config = $raw | ConvertFrom-Json -ErrorAction Stop

        if ($null -eq $config) {
            return [ordered]@{
                PrimaryMicId = $null
                SecondaryMicId = $null
                Hotkey = 'Ctrl+Alt+M'
            }
        }

        return [ordered]@{
            PrimaryMicId = [string]$config.PrimaryMicId
            SecondaryMicId = [string]$config.SecondaryMicId
            Hotkey = if ([string]::IsNullOrWhiteSpace([string]$config.Hotkey)) { 'Ctrl+Alt+M' } else { [string]$config.Hotkey }
        }
    }
    catch {
        throw "Unable to parse JSON configuration file '$Path': $($_.Exception.Message)"
    }
}

function Export-JsonConfiguration {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Configuration,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $Configuration | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Host "Saved configuration to $Path" -ForegroundColor Green
}

function Get-AvailableInputDevices {
    if (-not $IsWindows) {
        throw 'Microphone enumeration is currently implemented for Windows only.'
    }

    $deviceList = @()

    try {
        $captureDevices = Get-PnpDevice -Class AudioEndpoint -PresentOnly |
            Where-Object { $_.Status -eq 'OK' -and $_.FriendlyName -match '^Microphone' }
        foreach ($device in $captureDevices) {
            if (-not [string]::IsNullOrWhiteSpace($device.FriendlyName)) {
                $deviceList += [pscustomobject]@{
                    Id = [string]$device.InstanceId
                    Name = [string]$device.FriendlyName
                }
            }
        }
    }
    catch {
        throw "Failed to enumerate Windows input devices: $($_.Exception.Message)"
    }

    if ($deviceList.Count -eq 0) {
        throw 'No microphone devices were found.'
    }

    return $deviceList
}

function Get-SelectionChoice {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IEnumerable]$Choices,
        [Parameter(Mandatory = $true)][string]$PromptText
    )

    $index = 1
    foreach ($choice in $Choices) {
        Write-Host ("[{0}] {1}" -f $index, $choice.Name)
        $index++
    }

    $selection = Read-Host $PromptText
    if (-not ($selection -match '^[0-9]+$')) {
        throw 'Selection must be a numeric value.'
    }

    $choiceIndex = [int]$selection - 1
    if ($choiceIndex -lt 0 -or $choiceIndex -ge $Choices.Count) {
        throw 'Selection is out of range.'
    }

    return $Choices[$choiceIndex]
}

function Select-MicrophonePair {
    param(
        [Parameter()][System.Collections.IEnumerable]$DeviceList
    )

    if ($DeviceList -is [System.Array]) {
        $devices = @($DeviceList)
    }
    else {
        $devices = @($DeviceList)
    }

    $primary = Get-SelectionChoice -Choices $devices -PromptText 'Select the primary microphone (1-n):'
    $secondary = Get-SelectionChoice -Choices $devices -PromptText 'Select the secondary microphone (1-n):'

    if ($primary.Id -eq $secondary.Id) {
        throw 'Primary and secondary microphones must be different devices.'
    }

    return [pscustomobject]@{
        PrimaryMicId = $primary.Id
        SecondaryMicId = $secondary.Id
    }
}

function Set-MicrophoneMuteState {
    param(
        [Parameter(Mandatory = $true)][string]$DeviceId,
        [Parameter(Mandatory = $true)][bool]$Muted
    )

    if (-not $IsWindows) {
        throw 'This script currently supports literal microphone mute/unmute on Windows only.'
    }

    Write-Verbose ("Setting device {0} mute state to {1}" -f $DeviceId, $Muted)

    Add-CoreAudioInterop
    $audioEndpointId = $DeviceId -replace '^SWD\\MMDEVAPI\\', ''
    $hr = [CoreAudio.NativeMethods]::SetMute($audioEndpointId, $Muted)
    if ($hr -ne 0) {
        throw ("Unable to set microphone '{0}' mute state (HRESULT 0x{1:X8})." -f $DeviceId, $hr)
    }
}

function Add-CoreAudioInterop {
    if ($null -ne ([System.Management.Automation.PSTypeName]'CoreAudio.NativeMethods').Type) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace CoreAudio {
    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumeratorComObject { }

    [ComImport]
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(int dataFlow, uint stateMask, out IMMDeviceCollection devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
    }

    [ComImport]
    [Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice {
        int Activate(ref Guid interfaceId, uint classContext, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePointer);
    }

    [ComImport]
    [Guid("0BD7A1BE-7A1A-44DB-8397-C0F1E4A0B4D1")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceCollection { }

    [ComImport]
    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioEndpointVolume {
        int RegisterControlChangeNotify(IntPtr notify);
        int UnregisterControlChangeNotify(IntPtr notify);
        int GetChannelCount(out int count);
        int SetMasterVolumeLevel(float level, ref Guid eventContext);
        int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
        int GetMasterVolumeLevel(out float level);
        int GetMasterVolumeLevelScalar(out float level);
        int SetChannelVolumeLevel(uint channel, float level, ref Guid eventContext);
        int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid eventContext);
        int GetChannelVolumeLevel(uint channel, out float level);
        int GetChannelVolumeLevelScalar(uint channel, out float level);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool muted, ref Guid eventContext);
    }

    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool RegisterHotKey(IntPtr windowHandle, int id, uint modifiers, uint virtualKey);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool UnregisterHotKey(IntPtr windowHandle, int id);

        [DllImport("user32.dll")]
        public static extern int GetMessage(out Message message, IntPtr windowHandle, uint minimumMessage, uint maximumMessage);

        public static IMMDeviceEnumerator CreateDeviceEnumerator() {
            return (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
        }

        public static int SetMute(string id, bool muted) {
            IMMDevice device = null;
            IAudioEndpointVolume volume = null;
            try {
                int hr = CreateDeviceEnumerator().GetDevice(id, out device);
                if (hr != 0) {
                    return hr;
                }

                Guid interfaceId = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
                object interfacePointer;
                hr = device.Activate(ref interfaceId, 23, IntPtr.Zero, out interfacePointer);
                if (hr != 0) {
                    return hr;
                }
                volume = (IAudioEndpointVolume)interfacePointer;
                Guid eventContext = Guid.NewGuid();
                return volume.SetMute(muted, ref eventContext);
            }
            finally {
                if (volume != null) {
                    Marshal.ReleaseComObject(volume);
                }
                if (device != null) {
                    Marshal.ReleaseComObject(device);
                }
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct Message {
            public IntPtr WindowHandle;
            public uint MessageId;
            public IntPtr WParam;
            public IntPtr LParam;
            public uint Time;
            public int PointX;
            public int PointY;
        }
    }
}
'@
}

function Get-HotkeyRegistration {
    param(
        [Parameter(Mandatory = $true)][string]$Hotkey
    )

    $modifiers = [uint32]0
    $virtualKey = 0
    foreach ($part in ($Hotkey -split '\+')) {
        switch ($part) {
            'Ctrl' { $modifiers = $modifiers -bor 0x0002; continue }
            'Alt' { $modifiers = $modifiers -bor 0x0001; continue }
            'Shift' { $modifiers = $modifiers -bor 0x0004; continue }
            'Win' { $modifiers = $modifiers -bor 0x0008; continue }
            default {
                if ($part -match '^[A-Za-z0-9]$') {
                    $virtualKey = [int][char]$part.ToUpperInvariant()
                }
                elseif ($part -match '^F([1-9]|1[0-2])$') {
                    $virtualKey = 0x70 + [int]$Matches[1] - 1
                }
                else {
                    throw "Unsupported hotkey key '$part'."
                }
            }
        }
    }

    if ($virtualKey -eq 0) {
        throw "Hotkey '$Hotkey' does not contain a key."
    }

    return [pscustomobject]@{
        Modifiers = $modifiers
        VirtualKey = [uint32]$virtualKey
    }
}

function Test-ValidHotkey {
    param(
        [Parameter(Mandatory = $true)][string]$Hotkey
    )

    if ([string]::IsNullOrWhiteSpace($Hotkey)) {
        throw 'Hotkey cannot be empty.'
    }

    if ($Hotkey -match '^[A-Za-z0-9+\-]+$') {
        return
    }

    $supportsCommonModifiers = @('Ctrl', 'Alt', 'Shift', 'Win')
    $parts = $Hotkey -split '\+'
    foreach ($part in $parts) {
        if (-not ($supportsCommonModifiers -contains $part)) {
            if ($part -match '^[A-Za-z0-9]{1,2}$') {
                continue
            }
            throw "Unsupported hotkey token '$part' in '$Hotkey'."
        }
    }
}

function Resolve-EffectiveConfiguration {
    param(
        [Parameter()][string]$PrimaryMicId,
        [Parameter()][string]$SecondaryMicId,
        [Parameter()][string]$Hotkey,
        [Parameter()][switch]$SelectMicDevices,
        [Parameter()][string]$ConfigPath
    )

    $config = Import-JsonConfiguration -Path $ConfigPath

    if (-not [string]::IsNullOrWhiteSpace($PrimaryMicId)) {
        $config.PrimaryMicId = $PrimaryMicId
    }
    if (-not [string]::IsNullOrWhiteSpace($SecondaryMicId)) {
        $config.SecondaryMicId = $SecondaryMicId
    }
    if (-not [string]::IsNullOrWhiteSpace($Hotkey)) {
        $config.Hotkey = $Hotkey
    }

    if ($SelectMicDevices) {
        $devices = Get-AvailableInputDevices
        $selected = Select-MicrophonePair -DeviceList $devices
        $config.PrimaryMicId = $selected.PrimaryMicId
        $config.SecondaryMicId = $selected.SecondaryMicId
    }

    if ([string]::IsNullOrWhiteSpace($config.PrimaryMicId) -or [string]::IsNullOrWhiteSpace($config.SecondaryMicId)) {
        throw 'Both PrimaryMicId and SecondaryMicId must be supplied explicitly, via config, or via interactive selection.'
    }

    if ([string]::IsNullOrWhiteSpace($config.Hotkey)) {
        $config.Hotkey = 'Ctrl+Alt+M'
    }

    Test-ValidHotkey -Hotkey $config.Hotkey

    return [pscustomobject]@{
        PrimaryMicId = [string]$config.PrimaryMicId
        SecondaryMicId = [string]$config.SecondaryMicId
        Hotkey = [string]$config.Hotkey
    }
}

function Start-MicSwapMonitor {
    param(
        [Parameter(Mandatory = $true)][string]$PrimaryMicId,
        [Parameter(Mandatory = $true)][string]$SecondaryMicId,
        [Parameter(Mandatory = $true)][string]$Hotkey
    )

    Add-CoreAudioInterop
    $registration = Get-HotkeyRegistration -Hotkey $Hotkey
    $hotkeyId = 1
    if (-not [CoreAudio.NativeMethods]::RegisterHotKey([IntPtr]::Zero, $hotkeyId, $registration.Modifiers, $registration.VirtualKey)) {
        throw "Unable to register hotkey '$Hotkey'. The hotkey may already be in use."
    }

    $script:CurrentState = 'PrimaryActive'
    Write-Host ("Listening for hotkey '{0}' to swap between mic IDs '{1}' and '{2}'" -f $Hotkey, $PrimaryMicId, $SecondaryMicId) -ForegroundColor Cyan

    try {
        Set-MicrophoneMuteState -DeviceId $PrimaryMicId -Muted $false
        Set-MicrophoneMuteState -DeviceId $SecondaryMicId -Muted $true

        while ($true) {
            $message = New-Object CoreAudio.NativeMethods+Message
            $result = [CoreAudio.NativeMethods]::GetMessage([ref]$message, [IntPtr]::Zero, 0, 0)
            if ($result -le 0) {
                break
            }

            if ($message.MessageId -eq 0x0312 -and $message.WParam.ToInt32() -eq $hotkeyId) {
                if ($script:CurrentState -eq 'PrimaryActive') {
                    Set-MicrophoneMuteState -DeviceId $PrimaryMicId -Muted $true
                    Set-MicrophoneMuteState -DeviceId $SecondaryMicId -Muted $false
                    $script:CurrentState = 'SecondaryActive'
                }
                else {
                    Set-MicrophoneMuteState -DeviceId $PrimaryMicId -Muted $false
                    Set-MicrophoneMuteState -DeviceId $SecondaryMicId -Muted $true
                    $script:CurrentState = 'PrimaryActive'
                }
            }
        }
    }
    finally {
        [void][CoreAudio.NativeMethods]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId)
    }
}

$effectiveConfig = Resolve-EffectiveConfiguration -PrimaryMicId $PrimaryMicId -SecondaryMicId $SecondaryMicId -Hotkey $Hotkey -SelectMicDevices:$SelectMicDevices -ConfigPath $ConfigPath

if (-not [string]::IsNullOrWhiteSpace($SaveConfigPath)) {
    Export-JsonConfiguration -Configuration ([ordered]@{
        PrimaryMicId = $effectiveConfig.PrimaryMicId
        SecondaryMicId = $effectiveConfig.SecondaryMicId
        Hotkey = $effectiveConfig.Hotkey
    }) -Path $SaveConfigPath
}

Start-MicSwapMonitor -PrimaryMicId $effectiveConfig.PrimaryMicId -SecondaryMicId $effectiveConfig.SecondaryMicId -Hotkey $effectiveConfig.Hotkey
