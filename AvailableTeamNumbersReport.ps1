<#PSScriptInfo

    .VERSION 1.0

    .GUID ceb902ed-8bd8-4f3c-9c99-b1d894dda877

    .AUTHOR Vikas Sukhija

    .COMPANYNAME TechWizard.cloud

    .COPYRIGHT Vikas Sukhija

    .TAGS

    .LICENSEURI

    .PROJECTURI

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES 

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES

    .PRIVATEDATA

    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	5/19/2021 9:00 AM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AvailableTeamNumbersReport.ps1
    ===========================================================================

#>
<# 

    .DESCRIPTION 
    This will report the available phone numbers in Microsoft Teams
#> 
param (
  [string]$smtpserver,
  [string]$erroremail,
  [string]$from
 )
###################Functions############################
function New-FolderCreation
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$foldername
  )
	

  $logpath  = (Get-Location).path + "\" + "$foldername" 
  $testlogpath = Test-Path -Path $logpath
  if($testlogpath -eq $false)
  {
    #Start-ProgressBar -Title "Creating $foldername folder" -Timer 10
    $null = New-Item -Path (Get-Location).path -Name $foldername -Type directory
  }
}
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
    [String]$message,
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
      New-FolderCreation -foldername $folder
      foreach ($n in $Name)
      {$log += (Get-Location).Path + "\" + $folder + "\" + $n + "_" + $date1 + "_" + $time + "_.$Ext"}
      return $log
    }
    "Message"
    {
      $date = Get-Date
      $concatmessage = "|$date" + "|   |" + $message +"|  |" + "$Severity|"
      switch($Severity){
        "Information"{Write-Host -Object $concatmessage -ForegroundColor Green}
        "Warning"{Write-Host -Object $concatmessage -ForegroundColor Yellow}
        "Error"{Write-Host -Object $concatmessage -ForegroundColor Red}
      }
      
      Add-Content -Path $path -Value $concatmessage
    }
  }
} #Function Write-Log
#####################logs and reports###################
$log = Write-Log -Name "AvailableTeamNumbersReport-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "AvailableTeamNumbersReport-Report" -folder "Report" -Ext "csv"
$collection = @()

######connect to Skob and import modules ###################################
Write-Log -message "Start..................Script" -path $log
try 
{
  Connect-MicrosoftTeams
  Write-Log -Message "Connected to Teams module" -path $log
}
catch 
{
  $exception = $($_.Exception.Message)
  Write-Log -Message "$exception" -path $log -Severity Error
  Write-Log -Message "Exception has occured in connecting to Teams module" -path $log  -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error occured in connecting to Teams module - AvailableTeamNumbersReport" -Body $($_.Exception.Message)
  Exit;
}
##################start processing users##################

try
{
  $allnumbers = Get-CsOnlineTelephoneNumber -ResultSize 100000 | Select Id, ActivationState, CityCode,O365Region,InventoryType, TargetType, PortInOrderStatus
  Write-Log -message "Fetched Phonenumbers $($allnumbers.count) from Teams" -path $log
  $allassignednumbers = $allnumbers  | where{$_.TargetType -ne $null}
  Write-Log -message "Fetched Assigned Phonenumbers $($allassignednumbers.count) from Teams" -path $log
  $allunassignednumbers = $allnumbers  | where{$_.TargetType -eq $null}
  Write-Log -message "Fetched unAssigned Phonenumbers $($allunassignednumbers.count) from Teams" -path $log
  $getllcsonlineusernumbers = Get-CsOnlineUser -Filter {LineURI -ne $null} | Select UserprincipalName, LineURI
  Write-Log -message "Fetched all assigned users $($getllcsonlineusernumbers.count) from Teams" -path $log
  ############## adding as error is not geteingr eported and less numbers are fetched#############
  if($($allnumbers.count) -lt "8000"){
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error occured getting details from TEAMS AvailableTeamNumbersReport" -Body "Error occured getting details from TEAMS AvailableTeamNumbersReport"
    exit
  }
}
catch
{
  $exception = $($_.Exception.Message)
  Write-Log -Message "$exception" -path $log -Severity Error
  Write-Log -Message "Exception has occured getting details from TEAMS" -path $log  -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error occured getting details from TEAMS AvailableTeamNumbersReport" -Body $($_.Exception.Message)
  Exit;
}

##########Export to Report#################################
Write-Log -Message "Start exporting Report" -path $log
[System.Collections.ArrayList]$collection = @()
ForEach($voicenumber in $allnumbers) 
{
  $mcoll = "" | Select-Object Id, ActivationState, CityCode,O365Region,InventoryType, TargetType, PortInOrderStatus
  $mcoll.ID = $voicenumber.Id
  $mcoll.ActivationState = $voicenumber.ActivationState
  $mcoll.CityCode = $voicenumber.CityCode
  $mcoll.O365Region = $voicenumber.O365Region
  $mcoll.InventoryType = $voicenumber.InventoryType
  $mcoll.PortInOrderStatus = $voicenumber.PortInOrderStatus
  if($voicenumber.TargetType -eq "user")
  {
    $lineuri = $assigneduser = $null
    $lineuri = "tel:+" + $voicenumber.Id
    $assigneduser = $getllcsonlineusernumbers | where{$_.LineURI -eq $lineuri} | select userprincipalname
    $mcoll.TargetType = $assigneduser.userprincipalname
  }
  $collection.Add($mcoll) | out-null
}
Write-Log -Message "Data collected, export to CSV" -path $log
$collection | Export-Csv $Report1 -NoTypeInformation
Disconnect-MicrosoftTeams
##############################Recycle Logs##########################
Write-Log -Message "Recycle Logs" -path $log -Severity Information
Write-Log -message "Finish..................Script" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Report - AvailableTeamNumbersReport" -Body "Report - AvailableTeamNumbersReport" -Attachments $report1
#############################################################################################