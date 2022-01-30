<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	5/28/2020 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:      IntuneDeviceNotEvaluatedCleanup.ps1
    ===========================================================================
    .DESCRIPTION
     Any device with compliance status of "not evaluated" with an enrollment date of greater than 7 days and delete it.
#>
param (
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$email1 = $(Read-Host "Enter email Address for reports"),
  [string]$erroremail = $(Read-Host "Enter Address for Alerts and Errors"),
  [string]$reportOnly = $(Read-Host "Yes for Just report and No for removing duplicate records"),
  $Enrollmentdays = $(Read-Host "Enter teh number of days before which devices with unkown state will be deleted"),
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
$log = Write-Log -Name "Intunenotevalcleanup-Log" -folder "logs" -Ext "log"
$Report = Write-Log -Name "Intunenotevalcleanup-Report" -folder "Report" -Ext "csv"
Write-Log -Message "Start.......Script" -path $log
$collection = @()
$getdate = (Get-Date).AddDays(-$Enrollmentdays)
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
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error has occured loading AD?intune Module - IntuneDeviceNotEvaluatedCleanup" -Body $($_.Exception.Message)
  Exit
}

#####################process devicess with compliant state as unknown####################
try{
  $getalldevices = Get-IntuneManagedDevice | Get-MSGraphAllPages | where{($_.complianceState -eq "unknown") -and ($_.enrolledDateTime -lt $getdate )} | Select id,deviceName,enrolledDateTime,lastSyncDateTime,emailAddress,serialNumber,complianceState
  $countdevices = $getalldevices.count
  Write-Log -Message "Count of devices with unkown compliance state $countdevices" -path $log 

}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error occured fetching unkown devices" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error occured fetching duplicate entries - IntuneDeviceNotEvaluatedCleanup" -Body $($_.Exception.Message)
  Exit

}
############################Remove these devices from Intune##############################
if(( $countdevices -gt 0) -and ( $countdevices -lt $countofchanges)) {
  $getalldevices | ForEach-Object{
    $mcoll = "" | Select id,deviceName,enrolledDateTime,lastSyncDateTime,emailAddress,serialNumber,complianceState,status
    $mcoll.id = $_.id
    $mcoll.deviceName = $_.deviceName
    $mcoll.enrolledDateTime = $_.enrolledDateTime
    $mcoll.lastSyncDateTime = $_.lastSyncDateTime
    $mcoll.emailAddress = $_.emailAddress
    $mcoll.serialNumber = $_.serialNumber
    $mcoll.complianceState = $_.complianceState
    $srlnum = $_.serialNumber
    $emladd = $_.emailAddress
    $mgid = $_.ID
    try{
      if($reportonly -eq "No"){
        Remove-IntunemanagedDevice -manageddeviceID $_.id
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
      $collection +=$mcoll
  }
  $collection | Export-Csv $Report -NoTypeInformation
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Reports - IntuneDeviceNotEvaluatedCleanup" -Body "Reports - IntuneDeviceNotEvaluatedCleanup" -Attachments $report
}
elseif($countdevices  -gt $countofchanges)
{
  Write-Log -Message "Count is $countdevices  greater than $countofchanges" -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Count is $countdevices  greater than $countofchanges - IntuneDeviceNotEvaluatedCleanup" -Body "Error Count is $countdevices greater than $countofchanges - IntuneDeviceNotEvaluatedCleanup"
  exit;

}
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
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "IntuneDeviceNotEvaluatedCleanup - log" -Body "IntuneDeviceNotEvaluatedCleanup - log" -Attachments $log
################################################################################