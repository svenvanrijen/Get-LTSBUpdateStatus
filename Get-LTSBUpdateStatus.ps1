function Get-LTSBUpdateStatus {

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage="Path to file containing a list of computers.")]
        [ValidateNotNullOrEmpty()]
        [string]$computerlist,

        [Parameter(Mandatory = $true, HelpMessage="Path to logfile.")]
        [ValidateNotNullOrEmpty()]
        [string]$loglocation,

        [Parameter(Mandatory=$False, HelpMessage="Windows 10 LTSB build number.")]
        [ValidateSet('14393','10240')]
        [string] $BuildNumber = '10240'

    )

    #Helper function from https://keithga.wordpress.com/2017/05/21/new-tool-get-the-latest-windows-10-cumulative-updates/
    Function Select-LatestUpdate {
      [CmdletBinding(SupportsShouldProcess=$True)]
      Param(
          [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
          $Updates
      )
      Begin { 
          $MaxObject = $null
          $MaxValue = [version]::new("0.0")
      }
      Process {
          ForEach ( $Update in $updates ) {
              Select-String -InputObject $Update -AllMatches -Pattern "(\d+\.)?(\d+\.)?(\d+\.)?(\*|\d+)" |
              ForEach-Object { $_.matches.value } |
              ForEach-Object { $_ -as [version] } |
              ForEach-Object { 
                  if ( $_ -gt $MaxValue ) { $MaxObject = $Update; $MaxValue = $_ }
              }
          }
      }
      End { 
          $MaxObject | Write-Output 
      }
  }


    #Getting latest update number - based on https://keithga.wordpress.com/2017/05/21/new-tool-get-the-latest-windows-10-cumulative-updates/
    $lastKBArticleRAW = Invoke-WebRequest -Uri "https://support.microsoft.com/app/content/api/content/asset/en-us/4000816" |
    Select-Object -ExpandProperty Content |
    ConvertFrom-Json |
    Select-Object -ExpandProperty Links |
    Where-Object level -eq 2 |
    Where-Object text -match $BuildNumber |
    Select-LatestUpdate |
    Select-Object -First 1

    $lastKBArticle = "KB$($lastKBArticleRAW.articleId)"

    #Start logging
    Write-Host "`nLooking for $lastKBArticle" -ForegroundColor Green
    Add-Content -path $loglocation -Value "`n$(Get-Date) Start logging LTSB Update Status Check"
    Add-Content -path $loglocation -Value "`n$(Get-Date) Looking for $lastKBArticle"

    #Get computers to check from text file
    Write-Host "Getting content from $computerlist..." -ForegroundColor DarkYellow
    Add-Content -Path $loglocation -Value "`n$(Get-Date) Getting content from $computerlist..."
    $computers = Get-Content -path $computerlist

    Add-Content -Path $loglocation -Value "$(Get-Date) Check is going to run on these computers:"
    Add-Content -Path $loglocation -Value "$computers"

    $i = 0

    foreach ($computer in $computers) {

        $i++

        Write-Progress -Activity "Checking if computers are up-to-date..." `
            -Status "Checking computer $computer ($i / $($computers.count))" `
            -PercentComplete (($i / $computers.count) * 100)

        #check if computer is available
        $computeravailable = Test-Connection -ComputerName $computer -Quiet

        if ($computeravailable -eq $False) {
          
            Write-Host "`n$computer is not available at the moment." -ForegroundColor DarkRed
            Write-Host "Skipping $computer." -ForegroundColor DarkRed

            Add-Content -Path $loglocation -Value "`n$(Get-Date) $computer is unavailable at the moment, skipping $computer."
            
        }

        else {
          
            try {

                $installedhotfixes = Get-Hotfix -ComputerName $computer -ErrorVariable HotfixError |
                    Where-Object {$_.Description -eq "Security Update"} 
              
            }
            catch {
              
                Write-Host "`nRan into issue: $psitem" -ForegroundColor DarkRed
                Write-Host "Skipping $computer." -ForegroundColor DarkRed
                Add-Content -Path $loglocation -Value "`n$(Get-Date) Ran into issue: $psitem. Skipping $computer."
              
            }

            if (!$hotfixerror) {

                #Get all security hotfixes installed on computer
                Write-Host "`nGetting hotfixes installed on $computer." -ForegroundColor DarkYellow
                Add-Content -Path $loglocation -Value "`n$(Get-Date) Getting hotfixes installed on $computer."
              
                #Put only the KB-numbers in a list
                $kbnumbers = $installedhotfixes | Select-Object -ExpandProperty HotFixID
            
                #Check if one of the KB's macthes the latest monthly rollup
                Write-Host "`nChecking if $computer is up to date..." -ForegroundColor DarkYellow
                Add-Content -Path $loglocation -Value "`n$(Get-Date) Checking if $computer is up to date..."

                $ComputerIsUpToDate = $false

                foreach ($kbnumber in $kbnumbers) {

                    if ($kbnumber -eq $lastKBArticle) {

                        $ComputerIsUpToDate = $true
                
                    }

                }

                if ($ComputerIsUpToDate -eq $true) {

                    Write-Host "`n$computer is up to date!" -ForegroundColor DarkGreen
                    Add-Content -Path $loglocation -Value "`n$(Get-Date) $computer is up to date!"
              
                }

                else {
              
                    Write-Host "`n$computer is NOT up to date!" -ForegroundColor DarkRed
                    Add-Content -Path $loglocation -Value "`n$(Get-Date) $computer is NOT up to date!"
                    Add-Content -Path $loglocation -Value "`n$(Get-Date) Installed Security Updates:"
                    Add-Content -Path $loglocation -Value "$(Get-Date) $kbnumbers"

                }

            }

        }

    }

}



