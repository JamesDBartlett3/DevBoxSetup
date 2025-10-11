[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Get current PowerShell session process name
[string]$ps = (get-process -id $pid).ProcessName

# Build the command arguments to preserve WhatIf parameter
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
if ($WhatIfPreference) {
  $arguments += " -WhatIf"
}

# Check if script is running as administrator. If not, restart as administrator.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
      [Security.Principal.WindowsBuiltInRole] "Administrator")) {
 `
    Start-Process $ps $arguments `
    -Verb RunAs; exit 
}

$usbRoot = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"

# Only enumerate "Device Parameters" keys, skip protected ones
Get-ChildItem -Path $usbRoot -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" } |
ForEach-Object {
  $deviceParams = $_.PSPath
  if ($PSCmdlet.ShouldProcess($deviceParams, "Disable USB power management")) {
    if (-not $WhatIfPreference) {
      try {
        Set-ItemProperty -Path $deviceParams -Name "DeviceSelectiveSuspended" -Value 0 -Force
        Write-Host "Disabled power management for: $deviceParams"
      }
      catch {
        Write-Warning "Failed to update: $deviceParams"
      }
    }
    else {
      Write-Host "Would disable power management for: $deviceParams"
    }
  }
}
