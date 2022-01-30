<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	7/02/2019 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	GroupMemberCountReport.ps1
    ===========================================================================
    .DESCRIPTION
    This script is utilized to send number of members report in AD group to MGMT
#>
####################Load All Functions##############################
param (
  [string]$Group1 = $(Read-Host "Enter AD group for Monitoring Count"),
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors"),
  [array]$email= $(Read-Host "Enter Address for Email Report")
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
}

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
#################Check if logs folder is created##################
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}

$Reportpath  = (Get-Location).path + "\Report" 
$testReportpath = Test-Path -Path $Reportpath
if($testReportpath -eq $false)
{
  ProgressBar -Title "Creating Report folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Report -Type directory
}

##########################Load variables & Logs####################

$log = Write-Log -Name "log_ADGroupCount" -folder logs -Ext log
$Report = Write-Log -Name "Report_ADGroup" -folder Report -Ext csv
########################mainScript################################
Write-Log -Message "Start Script" -path $log 
Write-Log -Message "AD group name: $Group1" -path $log 
Write-Log -Message "SMTP server: $smtpserver" -path $log 
Write-Log -Message "From Address: $from" -path $log 
Write-Log -Message "Alert Email: $erroremail" -path $log 
Write-Log -Message "Report Email: $email" -path $log 
###################Load quest Module#############################
try
{
  Import-Module -Name activedirectory
  Write-Log -Message "AD Module Loaded" -path $log
}
catch
{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD Module Loaded" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error has occured loading AD Module - GroupMemberCountReport" -Body $($_.Exception.Message)
  Exit
}
#############################################################
Write-Log -Message "Start fetching all users from AD $Group1" -path $log
try
{
  $allADGroupusers = Get-ADGroup -identity $Group1 -Properties Member 
  $count = $allADGroupusers.member.count
  Write-Log -Message "Fetched all users in $Group1 - Count: $count" -path $log 
  Write-Log -Message "Extracting all users in $Group1 for report" -path $log 
  $allADGroupusers | Select-Object -Expand Member |
  Get-ADUser | select GivenName,SurName,Name,SamAccountName,UserPrincipalName | Export-Csv $Report -NoTypeInformation
  Write-Log -Message "Extracted all users in $Group1 for report" -path $log 
  $body = @"
  Hi All,

   Please find the status of member count:

   AD Group = $Group1
   Member count = $count

   Regards
   AutomatedAgent
"@
  Write-Log -Message "Sending Report to $email" -path $log 
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $email -bcc $erroremail -Subject "Group $Group1 - Member Count $count" -Body $body -Attachments $Report
}
catch
{
  $exception = $_.Exception
  Write-Log -Message "Error loading $Group1" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error loading $Group1 - AD group Count Monitor" -Body $($_.Exception.Message)
  Exit;
}

#######################Recycle reports & logs##############
$path1 = (Get-Location).path + "\Logs\"
	
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object {$_.CreationTime -lt $limit} |
Remove-Item -recurse -Force

Write-Log -Message "Script finished" -Path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Transcript Log - GroupMemberCountReport" -Body "Transcript Log - GroupMemberCountReport" -Attachments $log
##########################################################################