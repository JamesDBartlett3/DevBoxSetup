# Get current PowerShell executable path
[string]$ps = (Get-Process -Id $PID).Path

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")


# Check if script is running as administrator. If not, restart as administrator.
if (!$IsAdmin) {
	Start-Process "$ps" -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
	exit
}

# SSMS 2016
# powershell -Command "(Get-Content 'C:\Program Files (x86)\Microsoft SQL Server\130\Tools\Binn\ManagementStudio\ssms.pkgundef') -Replace '\[\`$RootKey\`$\\Themes\\{1ded0138-47ce-435e-84ef-9ec1f439b749}\]', '//[`$RootKey`$\Themes\{1ded0138-47ce-435e-84ef-9ec1f439b749}]' | Out-File 'C:\Program Files (x86)\Microsoft SQL Server\130\Tools\Binn\ManagementStudio\ssms.pkgundef'"

# SSMS 17
# powershell -Command "(Get-Content 'C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\ssms.pkgundef') -Replace '\[\`$RootKey\`$\\Themes\\{1ded0138-47ce-435e-84ef-9ec1f439b749}\]', '//[`$RootKey`$\Themes\{1ded0138-47ce-435e-84ef-9ec1f439b749}]' | Out-File 'C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\ssms.pkgundef'"

# SSMS 18
powershell -Command "(Get-Content 'C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\ssms.pkgundef') -Replace '\[\`$RootKey\`$\\Themes\\{1ded0138-47ce-435e-84ef-9ec1f439b749}\]', '//[`$RootKey`$\Themes\{1ded0138-47ce-435e-84ef-9ec1f439b749}]' | Out-File 'C:\Program Files (x86)\Microsoft SQL Server Management Studio 18\Common7\IDE\ssms.pkgundef'"

# SSMS 19
powershell -Command "(Get-Content 'C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\ssms.pkgundef') -Replace '\[\`$RootKey\`$\\Themes\\{1ded0138-47ce-435e-84ef-9ec1f439b749}\]', '//[`$RootKey`$\Themes\{1ded0138-47ce-435e-84ef-9ec1f439b749}]' | Out-File 'C:\Program Files (x86)\Microsoft SQL Server Management Studio 19\Common7\IDE\ssms.pkgundef'"