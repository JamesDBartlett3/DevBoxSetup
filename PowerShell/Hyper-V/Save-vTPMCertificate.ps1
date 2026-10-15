<#
.SYNOPSIS
    Imports or exports Hyper-V vTPM certificates.

.DESCRIPTION
    Exports the Hyper-V Shielded VM Encryption and Signing certificates,
    including their private keys, from the local Hyper-V host.

    Imports previously exported certificates into the
    "Shielded VM Local Certificates" certificate store.

    If the script is not running elevated, it restarts itself with
    administrative privileges.

.PARAMETER Action
    Specifies the operation to perform.

    Valid values:
        Export
        Import

.PARAMETER Path
    For Export, specifies the directory where the PFX files will be written.

    For Import, specifies the directory containing the PFX files.

.PARAMETER Password
    Specifies the password used to protect or open the PFX files.

.EXAMPLE
    .\Save-vTPMCertificate.ps1 `
        -Action Export `
        -Path 'C:\Backup\vTPM' `
        -Password 'MyPassword'

.EXAMPLE
    .\Save-vTPMCertificate.ps1 `
        -Action Import `
        -Path 'C:\Backup\vTPM' `
        -Password 'MyPassword'
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('Export', 'Import')]
    [string]$Action,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Password
)

$ErrorActionPreference = 'Stop'


# Self-elevate if necessary
$Principal = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Host 'Administrative privileges are required. Requesting elevation...'

    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile'
        '-File'
        $PSCommandPath
        '-Action'
        $Action
        '-Path'
        $Path
        '-Password'
        $Password
    )

    exit
}


# Create the export directory if necessary
if ($Action -eq 'Export' -and -not (Test-Path -LiteralPath $Path)) {
    New-Item `
        -ItemType Directory `
        -Path $Path `
        -Force |
        Out-Null
}

$Path = (Resolve-Path -LiteralPath $Path).Path

$SecurePassword = ConvertTo-SecureString `
    -String $Password `
    -AsPlainText `
    -Force

$StoreName = 'Shielded VM Local Certificates'
$StorePath = "Cert:\LocalMachine\$StoreName"


function Export-vTPMCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [SecureString]$Password
    )

    if (-not (Test-Path -LiteralPath $StorePath)) {
        throw "The certificate store '$StoreName' does not exist."
    }

    $Certificates = @(
        Get-ChildItem -Path $StorePath |
            Where-Object {
                $_.Subject -like 'CN=Shielded VM Encryption Certificate *' -or
                $_.Subject -like 'CN=Shielded VM Signing Certificate *'
            }
    )

    if ($Certificates.Count -eq 0) {
        throw "No Hyper-V vTPM certificates were found in '$StorePath'."
    }

    foreach ($Certificate in $Certificates) {

        if (-not $Certificate.HasPrivateKey) {
            throw "Certificate '$($Certificate.Subject)' does not have a private key."
        }

        if ($Certificate.Subject -like 'CN=Shielded VM Encryption Certificate *') {
            $CertificateType = 'Encryption'
        }
        elseif ($Certificate.Subject -like 'CN=Shielded VM Signing Certificate *') {
            $CertificateType = 'Signing'
        }
        else {
            continue
        }

        $FileName = '{0}-vTPM-{1}.pfx' -f `
            $env:COMPUTERNAME,
            $CertificateType

        $FilePath = Join-Path `
            -Path $Path `
            -ChildPath $FileName

        Write-Host "Exporting $CertificateType certificate..."

        Export-PfxCertificate `
            -Cert $Certificate `
            -FilePath $FilePath `
            -Password $Password `
            -ChainOption BuildChain `
            -Force |
            Out-Null

        Write-Host "  $FilePath" -ForegroundColor Green
    }

    Write-Host
    Write-Host 'Certificate export completed successfully.' `
        -ForegroundColor Green
}


function Import-vTPMCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [SecureString]$Password
    )

    if (-not (Test-Path -LiteralPath $StorePath)) {
        throw "The certificate store '$StoreName' does not exist."
    }

    $PfxFiles = @(
        Get-ChildItem `
            -LiteralPath $Path `
            -Filter '*.pfx' `
            -File
    )

    if ($PfxFiles.Count -eq 0) {
        throw "No PFX files were found in '$Path'."
    }

    foreach ($PfxFile in $PfxFiles) {

        Write-Host "Importing $($PfxFile.Name)..."

        $Certificate = Import-PfxCertificate `
            -FilePath $PfxFile.FullName `
            -CertStoreLocation $StorePath `
            -Password $Password

        if (-not $Certificate) {
            throw "Import failed for '$($PfxFile.FullName)'."
        }

        if (-not $Certificate.HasPrivateKey) {
            throw "Certificate '$($Certificate.Thumbprint)' was imported without its private key."
        }

        Write-Host "  Subject:    $($Certificate.Subject)"
        Write-Host "  Thumbprint: $($Certificate.Thumbprint)" `
            -ForegroundColor Green
    }

    Write-Host
    Write-Host 'Certificate import completed successfully.' `
        -ForegroundColor Green
}


switch ($Action) {

    'Export' {
        Export-vTPMCertificate `
            -Path $Path `
            -Password $SecurePassword
    }

    'Import' {
        Import-vTPMCertificate `
            -Path $Path `
            -Password $SecurePassword
    }
}