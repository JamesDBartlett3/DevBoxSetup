<#
.SYNOPSIS
    Adds VS Code to the Windows Explorer context menu.

.DESCRIPTION
    This script adds "Open with VS Code" context menu entries for files, folders,
    and folder backgrounds in Windows Explorer. It supports multiple VS Code editions
    (Stable and Insiders) and can detect existing installations automatically.

    The script requires administrator privileges and will prompt for elevation if needed.

.PARAMETER VSCodePath
    Optional. Specifies a custom path to Code.exe. If not provided, the script will
    automatically detect installed VS Code editions.

.PARAMETER All
    When specified, adds context menu entries for all detected VS Code installations
    without prompting for selection.

.PARAMETER RemoveExisting
    When specified, removes any existing VS Code context menu entries before adding new ones.

.PARAMETER Force
    When specified, skips all confirmation prompts and proceeds with default actions.

.EXAMPLE
    .\Add-VSCodeToExplorerContextMenu.ps1
    Runs the script interactively, detecting installations and prompting for choices.

.EXAMPLE
    .\Add-VSCodeToExplorerContextMenu.ps1 -All
    Adds context menu entries for all detected VS Code installations without prompting.

.EXAMPLE
    .\Add-VSCodeToExplorerContextMenu.ps1 -RemoveExisting -All
    Removes existing entries and adds entries for all detected installations.

.EXAMPLE
    .\Add-VSCodeToExplorerContextMenu.ps1 -VSCodePath "D:\Apps\VSCode\Code.exe"
    Adds context menu entries for a VS Code installation at a custom path.

.NOTES
    Author: James D. Bartlett III
    Requires: Administrator privileges
    
.LINK
    https://github.com/JamesDBartlett3/DevBoxSetup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Custom path to Code.exe")]
    [ValidateScript({ 
        if ($_ -and -not (Test-Path $_)) { 
            throw "The specified path does not exist: $_" 
        }
        return $true 
    })]
    [string]$VSCodePath,

    [Parameter(HelpMessage = "Add context menu for all detected installations without prompting")]
    [switch]$All,

    [Parameter(HelpMessage = "Remove existing VS Code context menu entries before adding new ones")]
    [switch]$RemoveExisting,

    [Parameter(HelpMessage = "Skip all confirmation prompts")]
    [switch]$Force
)

# If not running as admin, restart as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Build argument list including any parameters passed to the script
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($VSCodePath) { $argList += " -VSCodePath `"$VSCodePath`"" }
    if ($All) { $argList += " -All" }
    if ($RemoveExisting) { $argList += " -RemoveExisting" }
    if ($Force) { $argList += " -Force" }
    if ($WhatIfPreference) { $argList += " -WhatIf" }
    if ($VerbosePreference -eq 'Continue') { $argList += " -Verbose" }
    
    # Restart as admin using the same version of PowerShell that is currently running.
    $PSExePath = (Get-Process -Id $PID).Path
    Start-Process "$PSExePath" -Verb RunAs -ArgumentList $argList
    exit
}

# Animation function for progress indicators
function Show-AnimatedProgress {
  param([string]$Message, [scriptblock]$Action)
  
  $spinnerChars = @('|', '/', '-', '\')
  $spinnerIndex = 0
  
  # Start background job to run the action
  $job = Start-Job -ScriptBlock $Action
  
  Write-Host -NoNewline "$Message "
  
  # Animate spinner while job is running
  while ($job.State -eq 'Running') {
    Write-Host -NoNewline "`r$Message $($spinnerChars[$spinnerIndex]) " -ForegroundColor Cyan
    $spinnerIndex = ($spinnerIndex + 1) % $spinnerChars.Length
    Start-Sleep -Milliseconds 150
  }
  
  # Wait for job to complete and collect output/errors
  $result = Receive-Job -Job $job -Wait -ErrorAction SilentlyContinue
  
  # Check for errors in the job's error stream (this is where thrown exceptions go)
  $jobErrors = @()
  if ($job.ChildJobs.Count -gt 0 -and $job.ChildJobs[0].Error.Count -gt 0) {
    $jobErrors = $job.ChildJobs[0].Error
  }
  
  # Also check if the job state indicates failure
  $jobFailed = $job.State -eq 'Failed' -or $jobErrors.Count -gt 0
  
  Remove-Job -Job $job
  
  # Check if job failed or had errors
  if ($jobFailed) {
    Write-Host "`r$Message ✗ " -ForegroundColor Red
    foreach ($err in $jobErrors) {
      Write-Host "  Error: $($err.Exception.Message)" -ForegroundColor Red
    }
    return @{ Success = $false; Errors = $jobErrors }
  }
  
  # Clear spinner and show completion
  Write-Host "`r$Message ✓ " -ForegroundColor Green
  
  return @{ Success = $true; Result = $result }
}

# Function to find existing VS Code context menu entries
function Get-ExistingContextMenuEntries {
  $existingEntries = @()
  
  # Check file context menu entries
  # Match keys containing 'code' or 'vscode' (case-insensitive by default)
  # Use -LiteralPath because * is an actual registry key name, not a wildcard
  $fileKeys = Get-ChildItem -LiteralPath "HKCU:\Software\Classes\*\shell" -ErrorAction SilentlyContinue | 
    Where-Object { $_.PSChildName -match 'vscode|vs\s*code' }
  
  foreach ($key in $fileKeys) {
    $displayName = (Get-ItemProperty -Path $key.PSPath -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
    $iconPath = (Get-ItemProperty -Path $key.PSPath -Name 'Icon' -ErrorAction SilentlyContinue).'Icon'
    if ($displayName -or $iconPath) {
      $existingEntries += @{
        Location = "Files"
        KeyName = $key.PSChildName
        DisplayName = $displayName
        Icon = $iconPath
        Path = $key.PSPath
      }
    }
  }
  
  # Check folder context menu entries
  $folderKeys = Get-ChildItem -Path "HKCU:\Software\Classes\Directory\shell" -ErrorAction SilentlyContinue | 
    Where-Object { $_.PSChildName -match 'vscode|vs\s*code' }
  
  foreach ($key in $folderKeys) {
    $displayName = (Get-ItemProperty -Path $key.PSPath -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
    $iconPath = (Get-ItemProperty -Path $key.PSPath -Name 'Icon' -ErrorAction SilentlyContinue).'Icon'
    if ($displayName -or $iconPath) {
      $existingEntries += @{
        Location = "Folders"
        KeyName = $key.PSChildName
        DisplayName = $displayName
        Icon = $iconPath
        Path = $key.PSPath
      }
    }
  }
  
  # Check folder background context menu entries
  $bgKeys = Get-ChildItem -Path "HKCU:\Software\Classes\Directory\Background\shell" -ErrorAction SilentlyContinue | 
    Where-Object { $_.PSChildName -match 'vscode|vs\s*code' }
  
  foreach ($key in $bgKeys) {
    $displayName = (Get-ItemProperty -Path $key.PSPath -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
    $iconPath = (Get-ItemProperty -Path $key.PSPath -Name 'Icon' -ErrorAction SilentlyContinue).'Icon'
    if ($displayName -or $iconPath) {
      $existingEntries += @{
        Location = "Folder Backgrounds"
        KeyName = $key.PSChildName
        DisplayName = $displayName
        Icon = $iconPath
        Path = $key.PSPath
      }
    }
  }
  
  return ,$existingEntries
}

# Function to find all VS Code installations
function Find-AllVSCodeInstallations {
  $UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[1]
  
  # Define possible VS Code installation paths with metadata
  # Note: Each installation has a unique RegistryKey to avoid conflicts
  $possibleInstallations = @(
    @{
      Path = "C:\Users\$UserName\AppData\Local\Programs\Microsoft VS Code\Code.exe"
      Name = "VS Code"
      Edition = "Stable"
      RegistryKey = "vscode"
    },
    @{
      Path = "C:\Program Files\Microsoft VS Code\Code.exe"
      Name = "VS Code (System)"
      Edition = "Stable"
      RegistryKey = "vscode-system"
    },
    @{
      Path = "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
      Name = "VS Code (System x86)"
      Edition = "Stable"
      RegistryKey = "vscode-system-x86"
    },
    @{
      Path = "C:\Users\$UserName\AppData\Local\Programs\Microsoft VS Code Insiders\Code - Insiders.exe"
      Name = "VS Code Insiders"
      Edition = "Insiders"
      RegistryKey = "vscode-insiders"
    },
    @{
      Path = "C:\Program Files\Microsoft VS Code Insiders\Code - Insiders.exe"
      Name = "VS Code Insiders (System)"
      Edition = "Insiders"
      RegistryKey = "vscode-insiders-system"
    }
  )
  
  $foundInstallations = @()
  
  # Check each path
  foreach ($installation in $possibleInstallations) {
    if (Test-Path $installation.Path) {
      $foundInstallations += $installation
    }
  }
  
  # Try to find code.exe in PATH if nothing found yet
  if ($foundInstallations.Count -eq 0) {
    $codeInPath = Get-Command code -ErrorAction SilentlyContinue
    if ($codeInPath) {
      $foundInstallations += @{
        Path = $codeInPath.Source
        Name = "VS Code (from PATH)"
        Edition = "Stable"
        RegistryKey = "vscode"
      }
    }
  }
  
  return ,$foundInstallations
}

# Check for existing context menu entries
Write-Host "Checking for existing VS Code context menu entries..." -ForegroundColor Cyan
$existingEntries = Get-ExistingContextMenuEntries

if ($existingEntries.Count -gt 0) {
  Write-Host "`nFound $($existingEntries.Count) existing context menu entry/entries:" -ForegroundColor Yellow
  
  # Group by location for cleaner display
  $grouped = $existingEntries | Group-Object -Property Location
  foreach ($group in $grouped) {
    Write-Host "`n  $($group.Name):" -ForegroundColor Cyan
    foreach ($entry in $group.Group) {
      Write-Host "    • $($entry.DisplayName)" -ForegroundColor White
      if ($entry.Icon) {
        Write-Host "      Registry Key: $($entry.KeyName)" -ForegroundColor DarkGray
        Write-Host "      Icon: $($entry.Icon -replace ',0$', '')" -ForegroundColor DarkGray
      }
    }
  }
  
  # Handle based on parameters
  if ($RemoveExisting) {
    Write-Host "`nRemoving existing entries (-RemoveExisting specified)..." -ForegroundColor Yellow
    foreach ($entry in $existingEntries) {
      if ($PSCmdlet.ShouldProcess($entry.DisplayName, "Remove context menu entry")) {
        try {
          Remove-Item -Path $entry.Path -Recurse -Force -ErrorAction Stop
          Write-Host "  ✓ Removed: $($entry.DisplayName)" -ForegroundColor Green
        } catch {
          Write-Host "  ✗ Failed to remove: $($entry.DisplayName) - $_" -ForegroundColor Red
        }
      }
    }
    Write-Host ""
  } elseif ($Force) {
    Write-Host "`nContinuing (-Force specified)..." -ForegroundColor Green
  } else {
    Write-Host "`nDo you want to continue and add more entries? This may create duplicates." -ForegroundColor Yellow
    Write-Host "  [Y] Yes, continue" -ForegroundColor Cyan
    Write-Host "  [N] No, exit" -ForegroundColor Cyan
    Write-Host "  [R] Remove existing entries and start fresh" -ForegroundColor Cyan
    
    $continueChoice = Read-Host "`nYour choice"
    
    switch ($continueChoice.ToUpper()) {
      'Y' {
        Write-Host "`nContinuing..." -ForegroundColor Green
      }
      'R' {
        Write-Host "`nRemoving existing entries..." -ForegroundColor Yellow
        foreach ($entry in $existingEntries) {
          if ($PSCmdlet.ShouldProcess($entry.DisplayName, "Remove context menu entry")) {
            try {
              Remove-Item -Path $entry.Path -Recurse -Force -ErrorAction Stop
              Write-Host "  ✓ Removed: $($entry.DisplayName)" -ForegroundColor Green
            } catch {
              Write-Host "  ✗ Failed to remove: $($entry.DisplayName) - $_" -ForegroundColor Red
            }
          }
        }
        Write-Host ""
      }
      default {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit
      }
    }
  }
} else {
  Write-Host "No existing VS Code context menu entries found." -ForegroundColor Green
}

# Find VS Code installations
if ($VSCodePath) {
  # Custom path provided via parameter
  Write-Host "`nUsing custom VS Code path: $VSCodePath" -ForegroundColor Cyan
  $installations = @(@{
    Path = $VSCodePath
    Name = "VS Code (Custom)"
    Edition = "Stable"
    RegistryKey = "vscode"
  })
} else {
  Write-Host "`nSearching for VS Code installations..." -ForegroundColor Cyan
  $installations = Find-AllVSCodeInstallations
}

if ($installations.Count -eq 0) {
  Write-Host "`nNo VS Code installations found!" -ForegroundColor Red
  
  if ($Force) {
    Write-Host "Cannot proceed without VS Code installation. Exiting..." -ForegroundColor Red
    exit 1
  }
  
  Write-Host "Please enter the full path to Code.exe (or press Enter to exit):" -ForegroundColor Yellow
  $customPath = Read-Host
  
  if ([string]::IsNullOrWhiteSpace($customPath)) {
    Write-Host "Exiting..." -ForegroundColor Yellow
    exit
  }
  
  if (Test-Path $customPath) {
    $installations = @(@{
      Path = $customPath
      Name = "VS Code (Custom)"
      Edition = "Stable"
      RegistryKey = "vscode"
    })
  } else {
    Write-Host "The specified path does not exist: $customPath" -ForegroundColor Red
    exit
  }
}

# Display found installations
Write-Host "`nFound $($installations.Count) installation(s):" -ForegroundColor Green
for ($i = 0; $i -lt $installations.Count; $i++) {
  Write-Host "  [$($i + 1)] $($installations[$i].Name) - $($installations[$i].Path)" -ForegroundColor Cyan
}

# Let user select which installations to add
$selectedInstallations = @()

if ($installations.Count -eq 1) {
  # Only one installation found - use it
  $selectedInstallations = $installations
  Write-Host "`nAdding context menu for: $($installations[0].Name)" -ForegroundColor Yellow
} elseif ($All -or $Force) {
  # -All or -Force parameter specified - add all installations
  $selectedInstallations = $installations
  Write-Host "`nAdding context menu for all installations (-All or -Force specified)..." -ForegroundColor Green
} else {
  # Multiple installations - prompt user
  Write-Host "`nWhich installation(s) would you like to add to the context menu?" -ForegroundColor Yellow
  Write-Host "  [A] All installations" -ForegroundColor Cyan
  Write-Host "  [S] Select specific installation(s)" -ForegroundColor Cyan
  Write-Host "  [Q] Quit" -ForegroundColor Cyan
  
  $choice = Read-Host "`nYour choice"
  
  switch ($choice.ToUpper()) {
    'A' {
      $selectedInstallations = $installations
      Write-Host "Adding all installations..." -ForegroundColor Green
    }
    'S' {
      Write-Host "`nEnter the numbers of installations to add (comma-separated, e.g., 1,2):" -ForegroundColor Yellow
      $selection = Read-Host
      $numbers = $selection -split ',' | ForEach-Object { $_.Trim() }
      
      foreach ($num in $numbers) {
        if ($num -match '^\d+$') {
          $index = [int]$num - 1
          if ($index -ge 0 -and $index -lt $installations.Count) {
            $selectedInstallations += $installations[$index]
          }
        }
      }
      
      if ($selectedInstallations.Count -eq 0) {
        Write-Host "No valid installations selected. Exiting..." -ForegroundColor Red
        exit
      }
    }
    'Q' {
      Write-Host "Exiting..." -ForegroundColor Yellow
      exit
    }
    default {
      Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
      exit
    }
  }
}

Write-Host "`nSelected installation(s):" -ForegroundColor Green
foreach ($inst in $selectedInstallations) {
  Write-Host "  • $($inst.Name)" -ForegroundColor Cyan
}
Write-Host ""

# Track errors
$errorOccurred = $false
$errorMessages = @()

# Process each selected installation
foreach ($installation in $selectedInstallations) {
  $vsPath = $installation.Path
  $vsName = $installation.Name
  $regKey = $installation.RegistryKey
  $menuLabel = if ($installation.Edition -eq "Insiders") { "VS Code Insiders" } else { "VS Code" }
  
  Write-Host "`n--- Adding context menu for $vsName ---" -ForegroundColor Magenta
  
  # Check ShouldProcess for all operations on this installation
  if (-not $PSCmdlet.ShouldProcess($vsName, "Add context menu entries")) {
    Write-Host "  Skipped (WhatIf mode)" -ForegroundColor Yellow
    continue
  }
  
  # This will make it appear when you right click on a file
  # Use -LiteralPath because * is an actual registry key name, not a wildcard
  $result1 = Show-AnimatedProgress "Adding 'Open with $menuLabel' to file context menu" {
    try {
      New-Item -LiteralPath "HKCU:\Software\Classes\*\shell\$using:regKey" -Force -ErrorAction Stop | Out-Null
      Set-ItemProperty -LiteralPath "HKCU:\Software\Classes\*\shell\$using:regKey" -Name "(default)" -Value "Edit with $using:menuLabel" -ErrorAction Stop
      Set-ItemProperty -LiteralPath "HKCU:\Software\Classes\*\shell\$using:regKey" -Name "Icon" -Value "`"$using:vsPath`",0" -ErrorAction Stop
      New-Item -LiteralPath "HKCU:\Software\Classes\*\shell\$using:regKey\command" -Force -ErrorAction Stop | Out-Null
      Set-ItemProperty -LiteralPath "HKCU:\Software\Classes\*\shell\$using:regKey\command" -Name "(default)" -Value "`"$using:vsPath`" `"%1`"" -ErrorAction Stop
    } catch {
      throw "Failed to add file context menu: $_"
    }
  }
  if (-not $result1.Success) {
    $errorOccurred = $true
    $errorMessages += "Failed to add file context menu for $vsName"
  }
  
  # This will make it appear when you right click ON a folder
  $result2 = Show-AnimatedProgress "Adding 'Open with $menuLabel' to folder context menu" {
    try {
      New-Item -Path "HKCU:\Software\Classes\Directory\shell\$using:regKey" -Force -ErrorAction Stop | Out-Null
      Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\$using:regKey" -Name "(default)" -Value "Open Folder as $using:menuLabel Project" -ErrorAction Stop
      Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\$using:regKey" -Name "Icon" -Value "`"$using:vsPath`",0" -ErrorAction Stop
      New-Item -Path "HKCU:\Software\Classes\Directory\shell\$using:regKey\command" -Force -ErrorAction Stop | Out-Null
      Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\shell\$using:regKey\command" -Name "(default)" -Value "`"$using:vsPath`" `"%1`"" -ErrorAction Stop
    } catch {
      throw "Failed to add folder context menu: $_"
    }
  }
  if (-not $result2.Success) {
    $errorOccurred = $true
    $errorMessages += "Failed to add folder context menu for $vsName"
  }
  
  # This will make it appear when you right click INSIDE a folder
  $result3 = Show-AnimatedProgress "Adding 'Open with $menuLabel' to folder background context menu" {
    try {
      New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\$using:regKey" -Force -ErrorAction Stop | Out-Null
      Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\$using:regKey" -Name "(default)" -Value "Open Folder as $using:menuLabel Project" -ErrorAction Stop
      Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\$using:regKey" -Name "Icon" -Value "`"$using:vsPath`",0" -ErrorAction Stop
      New-Item -Path "HKCU:\Software\Classes\Directory\Background\shell\$using:regKey\command" -Force -ErrorAction Stop | Out-Null
      Set-ItemProperty -Path "HKCU:\Software\Classes\Directory\Background\shell\$using:regKey\command" -Name "(default)" -Value "`"$using:vsPath`" `"%V`"" -ErrorAction Stop
    } catch {
      throw "Failed to add folder background context menu: $_"
    }
  }
  if (-not $result3.Success) {
    $errorOccurred = $true
    $errorMessages += "Failed to add folder background context menu for $vsName"
  }
}

# Display final result
Write-Host ""
if ($WhatIfPreference) {
  Write-Host "WhatIf: No changes were made. Run without -WhatIf to apply changes." -ForegroundColor Yellow
} elseif ($errorOccurred) {
  Write-Host "Some operations failed:" -ForegroundColor Red
  foreach ($msg in $errorMessages) {
    Write-Host "  • $msg" -ForegroundColor Red
  }
  Write-Host "`nPlease check the errors above and try again." -ForegroundColor Yellow
  exit 1
} else {
  Write-Host "Context menu entries added successfully! ✓" -ForegroundColor Green
}
