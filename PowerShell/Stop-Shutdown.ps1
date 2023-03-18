Start-DTTitle {"Uptime: $((Get-Uptime).Hours) Hours, $((Get-Uptime).Minutes) Minutes"}
Clear-Host
while ($true) {
  shutdown -a -q | Out-Null
  Start-Sleep -Milliseconds 500
}