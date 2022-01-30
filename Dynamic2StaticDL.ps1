<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	7/25/2019 
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	Dynamic2StaticDL.ps1
    ===========================================================================
    .DESCRIPTION
    This Script is converting the Dynamic Dls to Static Dls
#>

param (
  [string]$dynamicgroup = $(Read-Host "Enter the dynamic Group"),
  [string]$staticgroup = $(Read-Host "Enter the static Group"),
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors"),
  $countofchanges = $(Read-Host "Enter Count of changes")
)
function Write-Log
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true,ParameterSetName = 'Create')]
    [array]$Name,
    [Parameter(Mandatory = $true,ParameterSetName = 'Create')]
    [string]$Ext,
    [Parameter(Mandatory = $true,ParameterSetName = 'Create')]
    [string]$folder,
    
    [Parameter(ParameterSetName = 'Create',Position = 0)][switch]$Create,
    
    [Parameter(Mandatory = $true,ParameterSetName = 'Message')]
    [String]$Message,
    [Parameter(Mandatory = $true,ParameterSetName = 'Message')]
    [String]$path,
    [Parameter(Mandatory = $false,ParameterSetName = 'Message')]
    [ValidateSet('Information','Warning','Error')]
    [string]$Severity = 'Information',
    
    [Parameter(ParameterSetName = 'Message',Position = 0)][Switch]$MSG
  )
  switch ($PsCmdlet.ParameterSetName) {
    "Create"
    {
      $log = @()
      $date1 = Get-Date -Format d
      $date1 = $date1.ToString().Replace("/", "-")
      $time = Get-Date -Format t
	
      $time = $time.ToString().Replace(":", "-")
      $time = $time.ToString().Replace(" ", "")
	
      foreach ($n in $Name)
      {$log += (Get-Location).Path + "\" + $folder + "\" + $n + "_" + $date1 + "_" + $time + "_.$Ext"}
      return $log
    }
    "Message"
    {
      $date = Get-Date
      $concatmessage = "|$date" + "|   |" + $Message +"|  |" + "$Severity|"
      switch($Severity){
        "Information"{Write-Host -Object $concatmessage -ForegroundColor Green}
        "Warning"{Write-Host -Object $concatmessage -ForegroundColor Yellow}
        "Error"{Write-Host -Object $concatmessage -ForegroundColor Red}
      }
      
      Add-Content -Path $path -Value $concatmessage
    }
  }
} #Function Write-Log
function ProgressBar
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    $Title,
    [Parameter(Mandatory = $true)]
    [int]$Timer
  )
	
  For ($i = 1; $i -le $Timer; $i++)
  {
    Start-Sleep -Seconds 1;
    Write-Progress -Activity $Title -Status "$i" -PercentComplete ($i /10 * 100)
  }
}

#################Check if logs folder is created####
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
####################Load variables and log##########
$log = Write-Log -Name "Dynamic2staticdl-Log" -folder "logs" -Ext "log"

########################Start Script################
Write-Log -Message "Start script" -path $log
try 
{
  Import-Module ActiveDirectory
  $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ExchangeServer -Authentication Kerberos
  import-pssession $session -AllowClobber
  Write-Log -Message "loaded.... AD and Exchange Module" -path $log
}
catch 
{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD and Exchange Module" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured loading AD and Exchange Module - Dynamic2staticDL" -Body $($_.Exception.Message)
  exit;
}


try{
  Write-Log -Message "Start fetching group membership information $dynamicgroup" -path $log
  $colldynamicgroup = Get-DynamicDistributionGroup -id $dynamicgroup
  $colldynamicgroupmem = Get-Recipient -RecipientPreviewFilter $colldynamicgroup.LdapRecipientFilter -resultsize unlimited | Select samaccountname
  Write-Log -Message "Finished fetching group membership information $dynamicgroup" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error fetching group membership information $dynamicgroup" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured fetching group membership information $dynamicgroup - Dynamic2staticDL" -Body $($_.Exception.Message)
  exit;
}

try{
  Write-Log -Message "Start fetching group membership information $staticgroup" -path $log
  $collstaticgroupmem =  Get-ADGroup  $staticgroup -Properties Member | 
  Select-Object -ExpandProperty Member |
  Get-ADUser |
  Select-Object samaccountname
  Write-Log -Message "Finished fetching group membership information $staticgroup" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error fetching group membership information $staticgroup" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured fetching group membership information $staticgroup - Dynamic2staticDL" -Body $($_.Exception.Message)
  exit;
}

try{
  Write-Log -Message "Start comparing $staticgroup $dynamicgroup" -path $log
  $changes = Compare-Object -ReferenceObject $colldynamicgroupmem -DifferenceObject $collstaticgroupmem -Property samaccountname | 
    Select-Object -Property samaccountname, @{
      n = 'State'
      e = {If ($_.SideIndicator -eq "=>"){"Removal" } Else { "Addition" }}
      }
   if($Changes){
      $removal = $Changes | Where-Object -FilterScript {$_.State -eq "Removal"} | Select -ExpandProperty samaccountname
      $Addition = $Changes | Where-Object -FilterScript {$_.State -eq "Addition"} | Select -ExpandProperty samaccountname
      
      if($Addition){
        $addcount = $Addition.count
        Write-Log -Message "Adding members to $staticgroup count $addcount" -path $log
        if($addcount -le $countofchanges){
          $Addition | ForEach-Object{
            $amem = $_
            Write-Log -Message "ADD  $amem  to $staticgroup" -path $log
            ADD-ADGroupMember -identity $staticgroup -Members $amem -Confirm:$false
          }
        }else{
          Write-Log -Message "ADD count $addcount is more than $countofchanges" -path $log -Severity Error
          Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured ADD count $addcount is more than $countofchanges - Dynamic2staticDL" -Body "Error has occured ADD count $addcount is more than $countofchanges - Dynamic2staticDL"
        }
        }
      if($removal){
          $remcount = $removal.count
          Write-Log -Message "Removing members from $staticgroup count $remcount" -path $log
          if($remcount -le $countofchanges){
            $removal | ForEach-Object{
              $rmem = $_
              Write-Log -Message "Remove $rmem from $staticgroup" -path $log
              Remove-ADGroupMember -identity $staticgroup -Members $rmem -Confirm:$false
            }     
          }else{
            Write-Log -Message "Remove count $remcount is more than $countofchanges" -path $log -Severity Error
         Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured Remove count $remcount is more than $countofchanges - Dynamic2staticDL" -Body "Error has occured Remove count $remcount is more than $countofchanges - Dynamic2staticDL"   
          } 
        }
      }        
 
  }
  catch{
  $exception = $_.Exception
  Write-Log -Message "Error comparing $staticgroup $dynamicgroup" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured comparing $staticgroup $dynamicgroup - Dynamic2staticDL" -Body $($_.Exception.Message)
  }
  
########################Recycle reports & logs##############
$path1 = $logpath
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Transcript Log - Dynamic2staticDL" -Body "Transcript Log - Dynamic2staticDL" -Attachments $log

###########################################################################