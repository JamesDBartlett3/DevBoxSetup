#region PSReadLine

# Bash-like tab completion & command history
# Original Source: https://www.rasmusolsson.dev/posts/powershell-autocomplete

# PSReadLine Mods
## Import PSReadLine when available
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Import-Module PSReadLine -ErrorAction Stop

        ## Tab - Gives a menu of suggestions
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        ## UpArrow will show the most recent command
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        ## DownArrow will show the least recent command
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        ## During auto completion, pressing arrow key up or down will move the cursor to the end of the completion
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        ## Enable Ctrl+Space to trigger MenuComplete completion
        Set-PSReadLineKeyHandler -Function MenuComplete -Chord 'Ctrl+@'

        $psReadLineOptionParameters = (Get-Command Set-PSReadLineOption).Parameters

        ## Show a list of suggestions during completion, instead of inline
        if ($psReadLineOptionParameters.ContainsKey('PredictionViewStyle')) {
            Set-PSReadLineOption -PredictionViewStyle ListView
        }
        ## Shows tooltip during completion
        if ($psReadLineOptionParameters.ContainsKey('ShowToolTips')) {
            Set-PSReadLineOption -ShowToolTips
        }
        ## Gives completions/suggestions from historical commands
        if ($psReadLineOptionParameters.ContainsKey('PredictionSource')) {
            Set-PSReadLineOption -PredictionSource History
        }
    }
    catch {
        Write-Warning "Could not configure PSReadLine: $($_.Exception.Message)"
    }
}

#endregion


#region General

## Enable WinGetCommandNotFound feature (from Microsoft PowerToys)
try {
    Import-Module Microsoft.WinGet.CommandNotFound -ErrorAction Stop
}
catch {
  $CommandNotFoundModuleFolder = "~\Documents\PowerShell\Modules\Microsoft.WinGet.CommandNotFound"
  if (Test-Path $CommandNotFoundModuleFolder) {
    # Find the latest installed version of the CommandNotFound module
    $CommandNotFoundModule = (Get-ChildItem -Path $CommandNotFoundModuleFolder -Filter *.psd1 -Recurse)[-1].FullName
        Import-Module $CommandNotFoundModule -ErrorAction SilentlyContinue
  }
}

## Override the default 'touch' command
function touch {
  # Params for passthrough to real touch.exe
  param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$Paths
  )
  Remove-Item Function:touch -ErrorAction SilentlyContinue
  & touch.exe @Paths
}

## Enable 'sudo' command in PowerShell
if (Get-Module -ListAvailable -Name gsudoModule) {
    Import-Module 'gsudoModule' -ErrorAction SilentlyContinue
}

#endregion


#region ChrisTitus Overrides

## Set the oh-my-posh theme
$themeName = "craver"
$localThemePath = "$env:POSH_THEMES_PATH\$themeName.omp.json"
function Get-Theme_Override {
  # Look for theme locally first, then fallback to the online version if not found
  if (Test-Path $localThemePath) {
    Write-Debug "Loading local theme from $localThemePath"
    oh-my-posh.exe init pwsh --config $localThemePath | Invoke-Expression
    return
  }
  Write-Warning "Local theme not found; loading from online source. Consider downloading the theme and placing it in $env:POSH_THEMES_PATH for faster loading and offline availability."
  oh-my-posh.exe init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$themeName.omp.json | Invoke-Expression
}

## Monkey-patch Write-Host to silence the 'Show-Help' message
$global:OriginalWriteHost = Get-Command Write-Host
function Write-Host {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0, ValueFromRemainingArguments=$true)]
        [System.Object]$Object,
        [Switch]$NoNewline,
        [System.Object]$Separator,
        [System.ConsoleColor]$ForegroundColor,
        [System.ConsoleColor]$BackgroundColor
    )
    process {
        if (([string]$Object) -match "Use 'Show-Help' to display help") {
            return
        }
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
    }
}

#endregion


#region Functions

# Define a function to test router firmware hash
function Test-RouterFirmwareHash {
    param(
        [Parameter(Mandatory)]
        [string]$FirmwarePath
    )

    # Resolve relative paths reliably (works for nested folders too)
    try {
        $FirmwarePath = (Resolve-Path $FirmwarePath).Path
    }
    catch {
        Write-Host "Firmware file not found: $FirmwarePath" -ForegroundColor Red
        return
    }

    # Build the adjacent .sha256 filename
    $directory = Split-Path $FirmwarePath
    $shaFile   = Join-Path $directory "sha256sum.sha256"

    if (-not (Test-Path $shaFile)) {
        Write-Host "SHA256 file not found: $shaFile" -ForegroundColor Red
        return
    }

    # Compute actual + expected hashes
    $actual   = (Get-FileHash $FirmwarePath -Algorithm SHA256).Hash
    $expected = ((Get-Content $shaFile) -split ' ')[0]

    # Compare + output
    if ($actual -eq $expected) {
        Write-Host "✔ Hash matches for $FirmwarePath" -ForegroundColor Green
    } else {
        Write-Host "✘ Hash mismatch for $FirmwarePath" -ForegroundColor Red
        Write-Host "Expected: $expected"
        Write-Host "Actual:   $actual"
    }
}

# ---------------------------------------------------------------------------
# Scan PowerShell files for commands that use a specified alias
#
# Examples:
#   Find-AliasUsage -AliasName where -Path .
#   Find-AliasUsage -AliasName cd -Path 'C:\Scripts'
#   Find-AliasUsage -AliasName where -Path $HOME -Recurse
#
# This uses PowerShell's parser rather than plain-text matching, so ordinary
# comments and strings containing the alias name are not reported.
# ---------------------------------------------------------------------------

function Find-AliasUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $AliasName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [switch] $Recurse
    )

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop

    $item = Get-Item -LiteralPath $resolvedPath.Path -Force

    if ($item.PSIsContainer) {
        $getChildItemParameters = @{
            LiteralPath = $item.FullName
            File        = $true
            Include     = '*.ps1', '*.psm1', '*.psd1'
            ErrorAction = 'SilentlyContinue'
        }

        if ($Recurse) {
            $getChildItemParameters.Recurse = $true
        }

        $files = Get-ChildItem @getChildItemParameters
    }
    else {
        $files = $item
    }

    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null

        try {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref] $tokens,
                [ref] $parseErrors
            )
        }
        catch {
            Write-Warning "Could not parse '$($file.FullName)': $($_.Exception.Message)"
            continue
        }

        if ($parseErrors) {
            foreach ($parseError in $parseErrors) {
                Write-Warning (
                    "Parse error in '{0}' at line {1}, column {2}: {3}" -f
                    $file.FullName,
                    $parseError.Extent.StartLineNumber,
                    $parseError.Extent.StartColumnNumber,
                    $parseError.Message
                )
            }
        }

        $whereCommandMatches = $ast.FindAll(
            {
                param($node)

                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -ieq $AliasName
            },
            $true
        )

        foreach ($match in $whereCommandMatches) {
            [PSCustomObject]@{
                File   = $match.Extent.File
                Line   = $match.Extent.StartLineNumber
                Column = $match.Extent.StartColumnNumber
                Code   = $match.Extent.Text
            }
        }
    }
}

#endregion


#region Aliases

# Define aliases for frequently used commands

Set-Alias trfh Test-RouterFirmwareHash
Set-Alias -Name "tc" -Value "Test-Connection"
Set-Alias -Name "g" -Value "git"
Set-Alias -Name "gs" -Value "git status"
Set-Alias -Name "ga" -Value "git add"
Set-Alias -Name "gco" -Value "git commit"
Set-Alias -Name "locksmith" -Value "C:\Program Files\PowerToys\modules\FileLocksmith\PowerToys.FileLocksmithUI.exe"

# Remove aliases that are not desired in this environment

$aliasesToRemove = @(
    'where' # Alias for Where-Object; remove it so bare 'where' invokes where.exe.
)

foreach ($aliasName in $aliasesToRemove) {
    $aliasPath = "Alias:\$aliasName"

    if (Test-Path -LiteralPath $aliasPath) {
        Remove-Item -LiteralPath $aliasPath -Force
    }
}

#endregion