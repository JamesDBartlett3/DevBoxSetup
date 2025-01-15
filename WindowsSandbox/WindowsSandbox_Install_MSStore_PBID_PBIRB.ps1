Start-Process powershell {-NoExit

  # Open the Downloads folder in the host system
  (Get-ChildItem 'C:\Host_SystemDrive\Users' -Directory | 
    Sort-Object -Property LastWriteTime -Descending)[0].FullName + '\Downloads' | Invoke-Item; 

  # Install the Microsoft Store
  Invoke-RestMethod 'https://bonguides.com/wsb/msstore' | Invoke-Expression; 

  # Install Power BI Desktop and Power BI Report Builder
  if ((Read-Host 'Automatically install Power BI Report Builder and Power BI Desktop (Y/N)?').ToUpper() -eq 'Y') {
    Invoke-RestMethod 'https://bonguides.com/winget' | Invoke-Expression; 
    winget search 'Power BI' --source=msstore --accept-source-agreements; 
    '9N3BL69HC2MC', '9NTXR16HNW1T' | ForEach-Object {
      winget install -e -i --id=$_ --source=msstore --accept-package-agreements
    }
  } else {
    Start-Process 'ms-windows-store://browse/?type=Apps&cat=Business&subcat=Data+%26+analytics'
  }

}