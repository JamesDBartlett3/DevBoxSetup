function Compress-HyperVHD {
    <#
	.SYNOPSIS
	Fully optimizes a Hyper-V VHD/X file.
	
	.DESCRIPTION
	Mounts the target VHD/X file as read-only, performs full optimization, and then dismounts it.
	
	.NOTES
	v1.0 January 28th, 2018
	(c) 2018 Eric Siron
	#>
    #requires -Module Hyper-V
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$Path,
        [Parameter()][Microsoft.Vhd.PowerShell.VhdCompactMode]$Mode = [Microsoft.Vhd.PowerShell.VhdCompactMode]::Full
    )
    try {
        $Path = (Resolve-Path -Path $Path -ErrorAction Stop).Path
        if ($Path -notmatch '.a?vhdx?$') { throw }
    }
    catch {
        throw('{0} is not a valid VHDX file.' -f $Path)
    }
    Mount-VHD -Path $Path -ReadOnly -ErrorAction Stop
    Optimize-VHD -Path $Path -Mode $Mode -ErrorAction Continue
    Dismount-VHD -Path $Path
}