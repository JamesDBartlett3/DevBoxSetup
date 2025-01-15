# TODO: Replace bonguides scripts with emdedded scripts that do the same thing
# Reference: https://serverfault.com/questions/1018220/how-do-i-install-an-app-from-windows-store-using-powershell
# Export-AppxPackage -Uri "https://www.microsoft.com/store/productId/9WZDNCRFJBMP" -Path "C:\Support\Store"



Start-Process powershell {-NoExit
  
  # Declare path locations:
  $hostUsers = 'C:\Host_SystemDrive\Users'
  $storeLocation = 'C:\Support\Store'

  function Export-AppxPackage {
    [CmdletBinding()]
    param (
      [string]$Uri,
      [string]$Path
    )

    begin {
      if (-Not (Test-Path "$Path")) {
        Write-Host -ForegroundColor Green "Creating directory $Path"
        New-Item -ItemType Directory -Force -Path "$Path"
      }
    }
      
    process {
      $StopWatch = [system.diagnostics.stopwatch]::startnew()
      $Path = (Resolve-Path $Path).Path
      #Get Urls to download
      Write-Host -ForegroundColor Yellow "Processing $Uri"
      $WebResponse = Invoke-WebRequest -UseBasicParsing -Method 'POST' -Uri 'https://store.rg-adguard.net/api/GetFiles' -Body "type=url&url=$Uri&ring=Retail" -ContentType 'application/x-www-form-urlencoded'
      $LinksMatch = ($WebResponse.Links | Where-Object {$_ -like '*.appx*'} | Where-Object {$_ -like '*_neutral_*' -or $_ -like '*_' + $env:PROCESSOR_ARCHITECTURE.Replace('AMD', 'X').Replace('IA', 'X') + '_*'} | Select-String -Pattern '(?<=a href=").+(?=" r)').matches.value
      $Files = ($WebResponse.Links | Where-Object {$_ -like '*.appx*'} | Where-Object {$_ -like '*_neutral_*' -or $_ -like '*_' + $env:PROCESSOR_ARCHITECTURE.Replace('AMD', 'X').Replace('IA', 'X') + '_*'} | Where-Object {$_ } | Select-String -Pattern '(?<=noreferrer">).+(?=</a>)').matches.value
      for ($i = 0; $i -lt $LinksMatch.Count; $i++) {
        $Array += , @($LinksMatch[$i], $Files[$i])
      }
      #Sort by filename descending
      $Array = $Array | Sort-Object @{Expression = {$_[1]}; Descending = $True}
      $LastFile = $null
      for ($i = 0; $i -lt $LinksMatch.Count; $i++) {
        $CurrentFile = $Array[$i][1]
        $CurrentUrl = $Array[$i][0]
        #Find first number index of current and last processed filename
        if ($CurrentFile -match '(?<number>\d)') {}
        $FileIndex = $CurrentFile.indexof($Matches.number)
        if ($LastFile -match '(?<number>\d)') {}
        $LastFileIndex = $LastFile.indexof($Matches.number)
    
        #If current filename product not equal to last filename product
        if (($CurrentFile.SubString(0, $FileIndex - 1)) -ne ($LastFile.SubString(0, $LastFileIndex - 1))) {
          #If file not already downloaded, add to the download queue
          if (-Not (Test-Path "$Path\$CurrentFile")) {
            "Downloading $Path\$CurrentFile"
            $FilePath = "$Path\$CurrentFile"
            $FileRequest = Invoke-WebRequest -Uri $CurrentUrl -UseBasicParsing #-Method Head
            [System.IO.File]::WriteAllBytes($FilePath, $FileRequest.content)
          }
          #Delete file outdated and already exist
        } elseif ((Test-Path "$Path\$CurrentFile")) {
          Remove-Item "$Path\$CurrentFile"
          "Removing $Path\$CurrentFile"
        }
        $LastFile = $CurrentFile
      }
      'Time to process: ' + $StopWatch.ElapsedMilliseconds
    }
  }

  # Download the Microsoft Store
  # Currently not working: Downloads dependencies, but fails to download Microsoft Store package
  # Export-AppxPackage -Uri "https://www.microsoft.com/store/productId/9WZDNCRFJBMP" -Path $storeLocation

  # Install the Microsoft Store
  # Get-ChildItem $storeLocation | Add-AppxPackage

  # Open the Downloads folder in the host system
  # TODO: Replace with a more reliable method
  (Get-ChildItem $hostUsers -Directory | 
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