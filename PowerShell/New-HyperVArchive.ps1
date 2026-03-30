<#
.SYNOPSIS
Create a minimal, importable archive of a Hyper-V VM in its current state.

.DESCRIPTION
Two modes:
  - ExportAndOptimize (safe, Microsoft-supported)
  - AdvancedFlatten (copy-only checkpoint flattening)

Original VHDX/AVHDX files are NEVER modified.

REQUIRES:
  - Hyper-V PowerShell module
  - Administrator privileges
#>

param(
    [Parameter(Mandatory)]
    [string]$VMName,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [ValidateSet("ExportAndOptimize", "AdvancedFlatten")]
    [string]$Mode = "ExportAndOptimize",

    # Optional: override automatic detection
    [string]$CheckpointAvhdxPath,

    # Optional compression
    [switch]$CompressWith7Zip,

    [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe"
)

# ---------------- Elevation guard (param must be first) ----------------
if (-not ([Security.Principal.WindowsPrincipal]
          [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole(
          [Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host "Elevation required. Relaunching as Administrator..."

    $argList = @("-NoProfile","-ExecutionPolicy Bypass","-File `"$PSCommandPath`"")

    foreach ($k in $PSBoundParameters.Keys) {
        $v = $PSBoundParameters[$k]
        if ($v -is [switch]) {
            if ($v) { $argList += "-$k" }
        } else {
            $argList += "-$k `"$v`""
        }
    }

    Start-Process powershell.exe -Verb RunAs -ArgumentList ($argList -join " ")
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------------

$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$WorkRoot  = Join-Path $OutputPath "$VMName-$Timestamp"
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

Write-Host "VM:   $VMName"
Write-Host "Mode: $Mode"
Write-Host "Work: $WorkRoot"

Write-Host "Stopping VM..."
Stop-VM -Name $VMName -Force

# ============================================================================
# MODE 1 — EXPORT + OPTIMIZE (SAFE, SUPPORTED)
# ============================================================================
if ($Mode -eq "ExportAndOptimize") {

    $ExportPath = Join-Path $WorkRoot "Export"
    New-Item -ItemType Directory -Force -Path $ExportPath | Out-Null

    Write-Host "Exporting VM..."
    Export-VM -Name $VMName -Path $ExportPath

    $VHDX = Get-ChildItem $ExportPath -Recurse -Filter *.vhdx |
            Where-Object { $_.Name -notlike "*.avhdx" } |
            Select-Object -First 1

    if (-not $VHDX) {
        throw "No VHDX found in exported VM."
    }

    Write-Host "Optimizing exported disk..."
    Optimize-VHD -Path $VHDX.FullName -Mode Full
}

# ============================================================================
# MODE 2 — ADVANCED FLATTEN (COPY-ONLY, ORIGINALS UNTOUCHED)
# ============================================================================
if ($Mode -eq "AdvancedFlatten") {

    Write-Host "Resolving checkpoint AVHDX..."

    if ($CheckpointAvhdxPath) {

        if (-not (Test-Path $CheckpointAvhdxPath)) {
            throw "Specified CheckpointAvhdxPath does not exist."
        }

        $ResolvedAvhdxPath = $CheckpointAvhdxPath
        Write-Host "Using user-specified AVHDX:"
        Write-Host "  $ResolvedAvhdxPath"
    }
    else {

        $Disks = Get-VMHardDiskDrive -VMName $VMName

        if ($Disks.Count -ne 1) {
            throw "VM has multiple disks attached. Specify -CheckpointAvhdxPath explicitly."
        }

        $ResolvedAvhdxPath = $Disks[0].Path

        if (-not $ResolvedAvhdxPath.ToLower().EndsWith(".avhdx")) {
            throw @"
AdvancedFlatten requires the VM to currently be on a checkpoint.

The active disk is a VHDX, not an AVHDX.
Either:
  - Apply the desired checkpoint first, or
  - Use ExportAndOptimize mode.
"@
        }

        Write-Host "Automatically detected active checkpoint disk:"
        Write-Host "  $ResolvedAvhdxPath"
    }

    $AvhdxInfo = Get-VHD -Path $ResolvedAvhdxPath
    if (-not $AvhdxInfo.ParentPath) {
        throw "Resolved AVHDX has no parent — invalid checkpoint disk."
    }

    $BaseDiskOriginal = $AvhdxInfo.ParentPath

    $DiskWork = Join-Path $WorkRoot "Disks"
    New-Item -ItemType Directory -Force -Path $DiskWork | Out-Null

    $BaseCopy  = Join-Path $DiskWork (Split-Path $BaseDiskOriginal -Leaf)
    $AvhdxCopy = Join-Path $DiskWork (Split-Path $ResolvedAvhdxPath -Leaf)

    Write-Host "Copying base disk (read-only source)..."
    Copy-Item $BaseDiskOriginal $BaseCopy

    Write-Host "Copying checkpoint disk (read-only source)..."
    Copy-Item $ResolvedAvhdxPath $AvhdxCopy

    Write-Host "Re-parenting copied AVHDX..."
    Set-VHD -Path $AvhdxCopy -ParentPath $BaseCopy

    Write-Host "Merging checkpoint into copied base..."
    Merge-VHD -Path $AvhdxCopy -DestinationPath $BaseCopy

    Write-Host "Optimizing merged disk..."
    Optimize-VHD -Path $BaseCopy -Mode Full
}

# ============================================================================
# OPTIONAL COMPRESSION
# ============================================================================
if ($CompressWith7Zip) {

    if (-not (Test-Path $SevenZipPath)) {
        throw "7-Zip not found at $SevenZipPath"
    }

    $ArchiveFile = "$WorkRoot.7z"

    Write-Host "Compressing archive with 7-Zip (maximum compression)..."
    & $SevenZipPath a `
        -t7z `
        -mx=9 `
        -m0=lzma2 `
        -md=256m `
        -ms=on `
        $ArchiveFile `
        $WorkRoot
}

Write-Host "✅ Archive complete."
Write-Host "✅ Original VM and disk chain were NOT modified."
