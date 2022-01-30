<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	11/4/2019 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	https://techwizard.cloud/  https://syscloudpro.com/
    Filename:     	IntuneDuplicateDeviceCleanup.ps1
    ===========================================================================
    .DESCRIPTION
    This script will cleanup the duplicarte records for the same device
#>
param (
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$email1 = $(Read-Host "Enter email Address for reports"),
  [string]$erroremail = $(Read-Host "Enter Address for Alerts and Errors"),
  [string]$reportOnly = $(Read-Host "Yes for Just report and No for removing duplicate records"),
  [string]$userId = $(Read-Host "Enter the Admin User id to conenct to Intune"),
  $pwd = $(Read-Host "Enter the passwrod" -AsSecureString),
  $countofchanges = $(Read-Host "Enter Count of changes to process before it breaks")
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
function Start-ProgressBar
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
    Write-Progress -Activity $Title -Status "$i" -PercentComplete ($i /100 * 100)
  }
}

#################Check if logs folder is created####
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
$Reportpath  = (Get-Location).path + "\Report" 
$testlogpath = Test-Path -Path $Reportpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating Report folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Report -Type directory
}

####################Load variables and log####################
$log = Write-Log -Name "Intunedupdevicecleanup-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "IntunedupdevicesNewOLD-Report" -folder "Report" -Ext "csv"
$Report2 = Write-Log -Name "IntunedupdevicesCleanup-Report" -folder "Report" -Ext "csv"
Write-Log -Message "Start.......Script" -path $log
$collection1 = @()
$collection2 = @()
##################Userid & password#################
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $userId, $pwd

################connect to modules###################
try
{
  Connect-MSGraph -PSCredential $Credential
  Write-Log -Message "Intune Module Loaded" -path $log
}
catch
{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD/Intune Module Loaded" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error has occured loading AD?intune Module - IntuneDuplicateDeviceCleanup" -Body $($_.Exception.Message)
  Exit
}

#####################process devicess####################
try{
  $getalldevices = Get-IntuneManagedDevice | Get-MSGraphAllPages
  $countdevices = $getalldevices.count
  Write-Log -Message "Count of devices $countdevices" -path $log 
  $Groupdevices = $getalldevices | Where-Object { -not [String]::IsNullOrWhiteSpace($_.serialNumber) } | Group-Object -Property serialNumber ###get where serail number is not blank
  $findduplicatedDevices = $Groupdevices | Where-Object {$_.Count -gt 1 }
  $countdupdevices = $findduplicatedDevices.count
  Write-Log -Message "Count of entries that are duplicate $countdupdevices" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error occured fetching duplicate entries" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error occured fetching duplicate entries - IntuneDuplicateDeviceCleanup" -Body $($_.Exception.Message)
  Exit

}
 Write-Log -Message "Count of entries that are duplicate $countdupdevices" -path $log
 
############################Find the devices for removal#######################
  foreach($entry in $findduplicatedDevices){
    $mcoll = "" | Select deviceName,emailAddress,serialNumber,operatingSystem,enrolledDateTime,lastSyncDateTime,ID,Status
    $newDevice = $entry.Group | Sort-Object -Property lastSyncDateTime -Descending | Select-Object -First 1
    $mcoll.deviceName = $newDevice.deviceName
    $mcoll.emailAddress = $newDevice.emailAddress
    $mcoll.serialNumber = $newDevice.serialNumber
    $mcoll.operatingSystem = $newDevice.operatingSystem
    $mcoll.enrolledDateTime = $newDevice.enrolledDateTime
    $mcoll.lastSyncDateTime = $newDevice.lastSyncDateTime
    $mcoll.ID= $newDevice.ID
    $mcoll.Status = "NewDevice"
    $collection1+=$mcoll
    $srlnum = $newDevice.serialNumber
    $emladd = $newDevice.emailAddress
    Write-Log -Message "NewDevice...........$srlnum - $emladd" -path $log 
    $mcoll=$null
    foreach($oldDevice in ($entry.Group | Sort-Object -Property lastSyncDateTime -Descending | Select-Object -Skip 1)){
      $mcoll = "" | Select deviceName,emailAddress,serialNumber,operatingSystem,enrolledDateTime,lastSyncDateTime,ID,Status
      $mcoll.deviceName = $oldDevice.deviceName
      $mcoll.emailAddress = $oldDevice.emailAddress
      $mcoll.serialNumber = $oldDevice.serialNumber
      $mcoll.operatingSystem = $oldDevice.operatingSystem
      $mcoll.enrolledDateTime = $oldDevice.enrolledDateTime
      $mcoll.lastSyncDateTime = $oldDevice.lastSyncDateTime
      $mcoll.ID= $oldDevice.ID
      $mcoll.Status = "OldDevice"
      $collection1+=$mcoll
      $srlnum = $oldDevice.serialNumber
      $emladd = $oldDevice.emailAddress
      Write-Log -Message "NewDevice...........$srlnum - $emladd" -path $log 
      $mcoll=$null
    }
  }
  $collection1 | Export-Csv $Report1 -NoTypeInformation
  $olddeivescollection = $collection1 | where{$_.status  -eq "OldDevice"}
  $olddeivesremovecount = $olddeivescollection.count
   Write-Log -Message "Count of devices $olddeivesremovecount" -path $log 
##################################################################################
$mcoll=$null
if(($olddeivesremovecount-gt 0) -and ($olddeivesremovecount -lt $countofchanges)) {
  $olddeivescollection | ForEach-Object{
    $error.clear()
    $mcoll = "" | Select deviceName,emailAddress,serialNumber,operatingSystem,enrolledDateTime,lastSyncDateTime,ID,Status
      $mcoll.deviceName = $_.deviceName
      $mcoll.emailAddress = $_.emailAddress
      $mcoll.serialNumber = $_.serialNumber
      $mcoll.operatingSystem = $_.operatingSystem
      $mcoll.enrolledDateTime = $_.enrolledDateTime
      $mcoll.lastSyncDateTime = $_.lastSyncDateTime
      $mcoll.ID= $_.ID
      $srlnum = $_.serialNumber
      $emladd = $_.emailAddress
      $mgid = $_.ID
      try{
      if($reportonly -eq "No"){
        Remove-IntunemanagedDevice -manageddeviceID $_.ID
        if($error){
          $mcoll.Status= "Error"
          Write-Log -Message "Error occured deleting entry $srlnum - $emladd - $mgid" -path $log -Severity Error 
        }else{
          $mcoll.Status= "Success"
          Write-Log -Message "Success deleting entry $srlnum - $emladd - $mgid" -path $log 
        }
        }
      if($reportonly -eq "Yes"){
         $mcoll.Status= "ReportOnlyMode"
         Write-Log -Message "Report onlymode - deleting entry $srlnum - $emladd - $mgid" -path $log
       } 
      }
      catch{
      
        $mcoll.ID= "Exception"
        $exception = $_.Exception
        Write-Log -Message "Error occured deleting entry $srlnum - $emladd - $mgid" -path $log -Severity Error 
        Write-Log -Message $exception -path $log -Severity error
      }
      $collection2 +=$mcoll
  }

  $collection2 | Export-Csv $Report2 -NoTypeInformation
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Reports - IntuneDuplicateDeviceCleanup" -Body "Reports - IntuneDuplicateDeviceCleanup" -Attachments $report1,$report2
}

elseif($olddeivesremovecount -gt $countofchanges)
{
  Write-Log -Message "Count is $olddeivesremovecount greater than $countofchanges" -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Count is $olddeivesremovecount greater than $countofchanges - IntuneDuplicateDeviceCleanup" -Body "Error Count is $olddeivesremovecount greater than $countofchanges - IntuneDuplicateDeviceCleanup"
  exit;

}

Write-Log -Message "Finish processing........ Duplicate entries" -path $log

##############################################################################
$path1 = $logpath
$path2 = $Reportpath

$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Get-ChildItem -Path $path2 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "IntuneDuplicateDeviceCleanup - log" -Body "IntuneDuplicateDeviceCleanup - log" -Attachments $log
################################################################################