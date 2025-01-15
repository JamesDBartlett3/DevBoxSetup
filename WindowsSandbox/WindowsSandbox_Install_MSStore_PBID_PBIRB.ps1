# TODO: Replace bonguides scripts with emdedded scripts that do the same thing
# Reference: https://serverfault.com/questions/1018220/how-do-i-install-an-app-from-windows-store-using-powershell

Start-Process powershell {-NoExit

  # Open the Downloads folder in the host system
  (Get-ChildItem 'C:\Host_SystemDrive\Users' -Directory | 
    Sort-Object -Property LastWriteTime -Descending)[0].FullName + '\Downloads' | Invoke-Item; 

  # Install the Microsoft Store
  Invoke-RestMethod 'bonguides.com/wsb/msstore' | Invoke-Expression; 

  # Install Power BI Desktop and Power BI Report Builder
  if ((Read-Host 'Install Power BI Report Builder and Power BI Desktop now (Y/N)?').ToUpper() -eq 'Y') {
    Invoke-RestMethod 'bonguides.com/winget' | Invoke-Expression; 
    winget search 'Power BI' --source=msstore --accept-source-agreements; 
    '9N3BL69HC2MC', '9NTXR16HNW1T' | ForEach-Object {
      winget install -e -i --id=$_ --source=msstore --accept-package-agreements
    }
  } else {
    # TODO: Wait until the Microsoft Store is not running, then launch it.
    Start-Process 'ms-windows-store://browse/?type=Apps&cat=Business&subcat=Data+%26+analytics'
  }

}