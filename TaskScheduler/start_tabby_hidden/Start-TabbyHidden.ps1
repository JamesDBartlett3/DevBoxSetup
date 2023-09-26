function Set-WindowState {

# Source of this function: https://gist.github.com/prasannavl/effd901e2460a651ad2c
  param(
    [Parameter()]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE',
    'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED',
    'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $State = 'SHOW',
    [Parameter()]
    $MainWindowHandle = (Get-Process -id $pid).MainWindowHandle
  )

  $WindowStates = @{
    'FORCEMINIMIZE' = 11
    'HIDE' = 0
    'MAXIMIZE' = 3
    'MINIMIZE' = 6
    'RESTORE' = 9
    'SHOW' = 5
    'SHOWDEFAULT' = 10
    'SHOWMAXIMIZED' = 3
    'SHOWMINIMIZED' = 2
    'SHOWMINNOACTIVE' = 7
    'SHOWNA' = 8
    'SHOWNOACTIVATE' = 4
    'SHOWNORMAL' = 1
  }

  $Win32ShowWindowAsync = Add-Type -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru -memberDefinition '
  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  '
  $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[($State)]) | Out-Null
  Write-Verbose ("Set Window Style on $MainWindowHandle to $State")

}

# Launch Tabby
Start-Process Tabby

# Declare an integer variable to hold the handle of Tabby's main window
[int32]$tabbyMainWindowHandle = 0

# Wait for Tabby to launch, and then hide the window
while ($tabbyMainWindowHandle -eq 0) {

  # Declare an array to hold the handles of all of Tabby's windows
  [array]$handles = (Get-Process Tabby).MainWindowHandle

  # After Tabby is launched, but before its main window opens, the $handles array will only contain zeroes.
  # Once the main window opens, its handle will be the only non-zero value in the array.
  # So, we keep a running sum of the values of the $handles array, and as soon as the sum is non-zero, we'll know
  # that the main window has opened, and that our running sum will be its handle.
  $tabbyMainWindowHandle += ($handles.ToInt32() | Measure-Object -Sum).Sum
  Start-Sleep -Milliseconds 500

}

# Call the Set-WindowState function to hide Tabby's main window
Set-WindowState -State HIDE -MainWindowHandle $tabbyMainWindowHandle
