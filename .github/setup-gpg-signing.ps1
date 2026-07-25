#Requires -Version 5.1
<#
.SYNOPSIS
    Sets up GPG commit signing for Git on Windows.

.DESCRIPTION
    This script imports GPG keys, configures the GPG agent with a long cache TTL,
    and sets up Git to sign all commits and tags globally.

.PARAMETER KeysPath
    Path to the directory containing public-key.asc and private-key.asc files.
    Defaults to the same directory as this script.

.PARAMETER KeyId
    The GPG key ID to use for signing.

.PARAMETER CacheTTL
    Cache TTL in days. Defaults to 400 days.

.EXAMPLE
    .\setup-gpg-signing.ps1
    
.EXAMPLE
    .\setup-gpg-signing.ps1 -KeysPath "C:\path\to\keys" -KeyId "ABCD1234"
#>

param(
    [string]$KeysPath = $PSScriptRoot,
    [Parameter(Mandatory = $true)]
    [string]$KeyId,
    [int]$CacheTTL = 400
)

$ErrorActionPreference = "Stop"

# Find GPG executable
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
    Write-Error "GPG executable not found. Please ensure GPG is installed and in your PATH."
    exit 1
}

# Find gpgconf executable
$GpgConfExe = Get-Command gpgconf -CommandType Application -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $GpgConfExe) {
    $gpgDir = Split-Path $GpgExe
    $potentialConf = Join-Path $gpgDir "gpgconf.exe"
    if (Test-Path $potentialConf) {
        $GpgConfExe = $potentialConf
    }
}

Write-Host "=== GPG Commit Signing Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Import keys
$publicKeyPath = Join-Path $KeysPath "public-key.asc"
$privateKeyPath = Join-Path $KeysPath "private-key.asc"

if (Test-Path $publicKeyPath) {
    Write-Host "Importing public key..." -ForegroundColor Yellow
    & $GpgExe --import $publicKeyPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Public key imported successfully." -ForegroundColor Green
    }
} else {
    Write-Warning "Public key not found at: $publicKeyPath"
}

if (Test-Path $privateKeyPath) {
    Write-Host "Importing private key..." -ForegroundColor Yellow
    & $GpgExe --import $privateKeyPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Private key imported successfully." -ForegroundColor Green
    }
} else {
    Write-Warning "Private key not found at: $privateKeyPath"
}

# Step 2: Set trust level to ultimate
Write-Host ""
Write-Host "Setting key trust level to ultimate..." -ForegroundColor Yellow
# Get full fingerprint and set trust via ownertrust import
$fingerprint = & $GpgExe --list-keys --with-colons $KeyId 2>&1 | Select-String "^fpr:" | Select-Object -First 1
if ($fingerprint) {
    $fpr = ($fingerprint -split ":")[9]
    # Trust level 6 = ultimate
    $oldEncoding = $OutputEncoding
    $OutputEncoding = [System.Text.Encoding]::ASCII
    try {
        "$($fpr):6:" | & $GpgExe --import-ownertrust 2>&1 | Out-Null
        Write-Host "  Trust level set." -ForegroundColor Green
    }
    finally {
        $OutputEncoding = $oldEncoding
    }
} else {
    Write-Warning "  Could not retrieve fingerprint for trust setting"
}

# Step 3: Configure GPG agent
Write-Host ""
Write-Host "Configuring GPG agent (cache TTL: $CacheTTL days)..." -ForegroundColor Yellow

$gpgHome = "$env:USERPROFILE\.gnupg"
if (-not (Test-Path $gpgHome)) {
    New-Item -ItemType Directory -Path $gpgHome -Force | Out-Null
}

$cacheTTLSeconds = $CacheTTL * 24 * 60 * 60  # Convert days to seconds
$agentConfig = @"
default-cache-ttl $cacheTTLSeconds
max-cache-ttl $cacheTTLSeconds
"@

Set-Content -Path "$gpgHome\gpg-agent.conf" -Value $agentConfig -Encoding ASCII
Write-Host "  GPG agent config written to: $gpgHome\gpg-agent.conf" -ForegroundColor Green

# Restart GPG agent
if (Test-Path $GpgConfExe) {
    & $GpgConfExe --kill gpg-agent 2>&1 | Out-Null
    Write-Host "  GPG agent restarted." -ForegroundColor Green
}

# Step 4: Configure Git
Write-Host ""
Write-Host "Configuring Git for commit signing..." -ForegroundColor Yellow

git config --global user.signingkey $KeyId
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global gpg.program $GpgExe

Write-Host "  Signing key: $KeyId" -ForegroundColor Green
Write-Host "  Commit signing: enabled" -ForegroundColor Green
Write-Host "  Tag signing: enabled" -ForegroundColor Green
Write-Host "  GPG program: $GpgExe" -ForegroundColor Green

# Step 5: Verify setup
Write-Host ""
Write-Host "Verifying setup..." -ForegroundColor Yellow
$keyCheck = & $GpgExe --list-secret-keys --keyid-format=long $KeyId 2>&1
if ($keyCheck -match $KeyId) {
    Write-Host "  Key $KeyId is available." -ForegroundColor Green
} else {
    Write-Warning "  Key $KeyId not found in keyring!"
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Make a test commit to trigger passphrase prompt" -ForegroundColor Gray
Write-Host "  2. Enter your passphrase once (cached for $CacheTTL days)" -ForegroundColor Gray
Write-Host "  3. Ensure your public key is added to GitHub:" -ForegroundColor Gray
Write-Host "     https://github.com/settings/keys" -ForegroundColor Gray
Write-Host ""
