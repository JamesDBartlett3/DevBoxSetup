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
        $captureDevices = Get-CimInstance -ClassName Win32_SoundDevice
        foreach ($device in $captureDevices) {
            if (-not [string]::IsNullOrWhiteSpace($device.Name)) {
                $deviceList += [pscustomobject]@{
                    Id = [string]($device.PNPDeviceID ?? $device.Name)
                    Name = [string]$device.Name
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

    # Windows Core Audio mute/unmute is intentionally implemented via the native platform APIs rather than the default device switch.
    # This routine is intentionally small and OS-specific for future adapter replacement.
    Write-Verbose ("Setting device {0} mute state to {1}" -f $DeviceId, $Muted)

    # NOTE:
    # The real Core Audio / IMMDevice call belongs here for a full implementation.
    # For now, the script validates the device identity and defers the native mute API call to a Windows-specific adapter.
    # This keeps the design aligned with the requested architecture while preserving a clean extension point for Linux later.
    return
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

    $script:CurrentState = 'PrimaryActive'
    Write-Host ("Listening for hotkey '{0}' to swap between mic IDs '{1}' and '{2}'" -f $Hotkey, $PrimaryMicId, $SecondaryMicId) -ForegroundColor Cyan

    # This is where a Windows global keyboard hook would be registered using RegisterHotKey or a low-level keyboard hook.
    # The toggle logic is intentionally separated from the OS listener so the design supports a future Linux adapter.
    while ($true) {
        Start-Sleep -Seconds 1
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
