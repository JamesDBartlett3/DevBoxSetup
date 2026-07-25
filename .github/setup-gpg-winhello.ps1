#Requires -Version 5.1
<#
.SYNOPSIS
    Installs and configures gpg-winhello for Windows Hello GPG authentication.

.DESCRIPTION
    This script downloads the latest release of gpg-winhello, installs it to the user's
    local app data folder, and initiates the enrollment and configuration process.
    
    gpg-winhello allows you to use Windows Hello (Fingerprint/PIN) to unlock your GPG key
    instead of typing a passphrase every time.

.EXAMPLE
    .\setup-gpg-winhello.ps1

.EXAMPLE
    .\setup-gpg-winhello.ps1 -VirusTotalApiKey "YOUR_API_KEY"

.EXAMPLE
    .\setup-gpg-winhello.ps1 -VirusTotalApiKey "YOUR_API_KEY" -VirusTotal_IgnoreSuspicious

.EXAMPLE
    .\setup-gpg-winhello.ps1 -VirusTotalApiKey "YOUR_API_KEY" -VirusTotal_IgnoreAll

.EXAMPLE
    .\setup-gpg-winhello.ps1
    Prompts for manual acknowledgement that the automated VirusTotal check is being bypassed.
#>

param(
    [string]$VirusTotalApiKey,
    [switch]$VirusTotal_IgnoreSuspicious,
    [switch]$VirusTotal_IgnoreAll
)

$ErrorActionPreference = "Stop"
$Repo = "splack/gpg-winhello"
$InstallDir = "$env:LOCALAPPDATA\Programs\gpg-winhello"
$ExeName = "gpg-winhello.exe"

Write-Host "=== GPG Windows Hello Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check for GPG
$GpgExe = Get-Command gpg -CommandType Application -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $GpgExe) {
    $commonPaths = @(
        "C:\Program Files\Git\usr\bin\gpg.exe",
        "C:\Program Files (x86)\Git\usr\bin\gpg.exe",
        "C:\Program Files\GnuPG\bin\gpg.exe",
        "C:\Program Files (x86)\GnuPG\bin\gpg.exe"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $GpgExe = $path
            break
        }
    }
}

if (-not $GpgExe) {
    Write-Error "GPG is not installed or not in PATH. Please install Gpg4win or Git for Windows first."
    exit 1
}

# Add GPG to PATH for this session if it wasn't found automatically
# This ensures gpg-winhello can find gpg-connect-agent if needed
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    $gpgDir = Split-Path $GpgExe
    $env:PATH = "$gpgDir;$env:PATH"
    Write-Host "  Added $gpgDir to PATH for this session." -ForegroundColor Gray
}

# Step 2: Get latest release URL
Write-Host "Fetching latest release info from GitHub..." -ForegroundColor Yellow
try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
    $downloadUrl = $latestRelease.assets | Where-Object { $_.name -eq $ExeName } | Select-Object -ExpandProperty browser_download_url
    $hashUrl = $latestRelease.assets | Where-Object { $_.name -eq "$ExeName.sha256" } | Select-Object -ExpandProperty browser_download_url
    $version = $latestRelease.tag_name
    
    if (-not $downloadUrl) {
        throw "Could not find $ExeName in the latest release ($version)."
    }
    Write-Host "  Found version: $version" -ForegroundColor Green
}
catch {
    Write-Error "Failed to fetch release info: $_"
    exit 1
}

# Step 3: Download and Install
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$outputPath = Join-Path $InstallDir $ExeName
Write-Host "Downloading $ExeName to $outputPath..." -ForegroundColor Yellow

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath
    Write-Host "  Download complete." -ForegroundColor Green
}
catch {
    Write-Error "Failed to download file: $_"
    exit 1
}

# Step 3.1: Verify Hash
if ($hashUrl) {
    Write-Host "Verifying SHA256 hash..." -ForegroundColor Yellow
    try {
        $expectedHashContent = Invoke-RestMethod -Uri $hashUrl
        # The file usually contains "HASH  filename", so we split and take the first part
        $expectedHash = ($expectedHashContent -split '\s+')[0].Trim()
        
        $fileHash = Get-FileHash -Path $outputPath -Algorithm SHA256
        if ($fileHash.Hash -eq $expectedHash) {
            Write-Host "  Hash verification passed." -ForegroundColor Green
        } else {
            Write-Error "Hash verification failed!`nExpected: $expectedHash`nActual:   $($fileHash.Hash)"
            exit 1
        }
    }
    catch {
        Write-Warning "Could not verify hash: $_"
    }
} else {
    Write-Warning "No SHA256 checksum file found in release assets. Skipping hash verification."
}

# Step 3.2: VirusTotal Check
$fileHashStr = (Get-FileHash -Path $outputPath -Algorithm SHA256).Hash
$vtGuiUrl = "https://www.virustotal.com/gui/file/$fileHashStr"

if ($VirusTotalApiKey) {
    Write-Host "Checking file hash with VirusTotal..." -ForegroundColor Yellow
    $vtApiUrl = "https://www.virustotal.com/api/v3/files/$fileHashStr"
    
    try {
        $headers = @{ "x-apikey" = $VirusTotalApiKey }
        $response = Invoke-RestMethod -Uri $vtApiUrl -Headers $headers -Method Get
        
        $stats = $response.data.attributes.last_analysis_stats
        $malicious = $stats.malicious
        $suspicious = $stats.suspicious
        
        if ($malicious -eq 0 -and $suspicious -eq 0) {
            Write-Host "  VirusTotal check passed (0 malicious, 0 suspicious)." -ForegroundColor Green
        } else {
            Write-Warning "  VirusTotal flagged this file! Malicious: $malicious, Suspicious: $suspicious"
            Write-Warning "  See report: $vtGuiUrl"
            Write-Host "  Note: This checks the actual binary content. URL checks may be clean even if the file is flagged." -ForegroundColor Gray
            Write-Host "        False positives are common for small, niche tools." -ForegroundColor Gray

            $canIgnoreMalicious = $VirusTotal_IgnoreAll.IsPresent
            $canIgnoreSuspicious = $VirusTotal_IgnoreAll.IsPresent -or $VirusTotal_IgnoreSuspicious.IsPresent

            if ($malicious -gt 0 -and -not $canIgnoreMalicious) {
                Write-Error "VirusTotal reported malicious detections. Re-run with -VirusTotal_IgnoreAll to continue anyway."
                exit 1
            }

            if ($suspicious -gt 0 -and -not $canIgnoreSuspicious) {
                Write-Error "VirusTotal reported suspicious detections. Re-run with -VirusTotal_IgnoreSuspicious or -VirusTotal_IgnoreAll to continue anyway."
                exit 1
            }

            if ($malicious -gt 0) {
                Write-Warning "  Continuing because -VirusTotal_IgnoreAll was specified."
            } elseif ($suspicious -gt 0) {
                if ($VirusTotal_IgnoreAll.IsPresent) {
                    Write-Warning "  Continuing because -VirusTotal_IgnoreAll was specified."
                } else {
                    Write-Warning "  Continuing because -VirusTotal_IgnoreSuspicious was specified."
                }
            }
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Warning "  File hash not found in VirusTotal database (it might be too new)."
            Write-Host "  You can upload it manually here: $vtGuiUrl" -ForegroundColor Gray
        } else {
            Write-Warning "  VirusTotal check failed: $_"
        }
    }
} else {
    Write-Warning "VirusTotal API key not provided. The automated VirusTotal file hash check will be bypassed."
    
    Write-Host "1. Check the file hash (most accurate):" -ForegroundColor Gray
    Write-Host "   $vtGuiUrl" -ForegroundColor Blue
    
    Write-Host "2. Check the download URL (if file hash not found):" -ForegroundColor Gray
    $vtUrlSearch = "https://www.virustotal.com/gui/search/" + $downloadUrl
    Write-Host "   $vtUrlSearch" -ForegroundColor Blue

    Write-Host ""
    Write-Host "Please verify the file is safe before continuing." -ForegroundColor Yellow
    Write-Host "Type 'bypass' to acknowledge that the automated VirusTotal check is being bypassed, or press Enter to abort:" -ForegroundColor Yellow
    $acknowledgement = Read-Host
    if ($acknowledgement.Trim() -ine 'bypass') {
        exit 1
    }
}

# Unblock the file (since it was downloaded from the internet)
Unblock-File -Path $outputPath

# Step 4: Enroll
Write-Host ""
Write-Host "=== Enrollment ===" -ForegroundColor Cyan
Write-Host "You will now be prompted to enroll your GPG passphrase with Windows Hello." -ForegroundColor White
Write-Host "1. A dialog will appear asking for your GPG passphrase." -ForegroundColor Gray
Write-Host "2. Then Windows Hello will prompt you to authenticate (Fingerprint/PIN)." -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to start enrollment..." -NoNewline
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

& $outputPath enroll
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Enrollment successful." -ForegroundColor Green
} else {
    Write-Error "Enrollment failed."
    exit 1
}

# Step 5: Configure
Write-Host ""
Write-Host "=== Configuration ===" -ForegroundColor Cyan
Write-Host "Configuring GPG agent to use gpg-winhello..." -ForegroundColor Yellow

& $outputPath config
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Configuration successful." -ForegroundColor Green
} else {
    Write-Error "Configuration failed."
    exit 1
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Your GPG agent is now configured to use Windows Hello."
Write-Host "Try signing a commit or file to test it!"
