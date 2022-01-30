<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	3/4/2020 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	BulkProcessingTeamsOnlyMode.ps1
    ===========================================================================
    .DESCRIPTION
    This script will bulk add or remove users to teams only mode
#>
param (
  [string]$Userlist = $(Read-Host "Enter the text file path that contains userprincipalnames"),
  [string]$Operation = $(Read-Host "Type Enable for Enabling Teams Only mode and Disable for Island mode"),
  [string]$domain = $(Read-Host "Type Onmicrosoft Domain"),
  [string]$groupoperation = $(Read-Host "Type Yes if you want to use AD group or No if you want to avoid AD group operation"),
  [string]$group = $(Read-Host "Type AD group that you want to use")
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
} #Function Start-ProgressBar

function LaunchSOL
{
  param
  (
    $Domain,
    $UserCredential
  )
	
  Write-Host -Object "Enter Skype Online Credentials" -ForegroundColor Green
  $CSSession = New-CsOnlineSession -Credential $UserCredential -OverrideAdminDomain $Domain -Verbose
  Import-PSSession -Session $CSSession -Prefix "SOL"
  return $UserCredential
}
Function RemoveSOL
{
  $Session = Get-PSSession | Where-Object -FilterScript { $_.ComputerName -like "*.online.lync.com" }
  Remove-PSSession $Session
}

#################Check if logs folder is created##################
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
####################Load variables and log#######################
$log = Write-Log -Name "BulkADDRemoveTeamsonly-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "BulkADDRemoveTeamsonly-Report" -folder "Report" -Ext "csv"

$users = Get-Content $Userlist
$collection = @()
Write-Log -Message "Start Script" -path $log

######connect to Skob for checking user identity##########
 try {
    LaunchSOL -Domain $Domain -allowclobber
    Write-Log -Message "Connected to SKOBOnline" -path $log }
    catch 
    {
      $exception = $($_.Exception.Message)
      Write-Log -Message "$exception" -path $log -Severity Error
      Write-Log -Message "Exception has occured in connecting to SOL" -path $log  -Severity Error
      Exit;
    }
##################start processing users########################

if($Operation -eq "Enable"){
  Start-ProgressBar -Title "Enable operation selected" -Timer 10
  Write-Log -Message "Enable operation selected" -path $log 
  
  if($users.count -gt "0"){
    $users | ForEach-Object{
      $error.clear()
      $UPN = $_.trim()
      $mcoll = "" | Select UPN, TeamModeStatus, ADGroupSTatus
      $mcoll.UPN = $UPN
      Write-Log -Message "Processing Enable operation on $UPN" -path $log
      Grant-SOLCsTeamsUpgradePolicy -PolicyName UpgradeToTeams -Identity $UPN
      if($error){
        $mcoll.TeamModeStatus = "Error"
        Write-Log -Message "Error Processing Enable operation on $UPN" -path $log

      }
      else{
        $mcoll.TeamModeStatus= "Success"
        Write-Log -Message "Successful Processing Enable operation on $UPN" -path $log
       if($groupoperation -eq "Yes") {
             Write-Log -Message "ADD user $UPN to $group" -path $log
             $getaduser = Get-ADUser -Filter {UserPrincipalName -eq $UPN}
        
          Add-ADGroupMember -Identity $group -Members $getaduser.SamAccountName
          if($error){
            $mcoll.ADGroupSTatus = "Error"
            Write-Log -Message "Error Adding $upn operation on  $group" -path $log
          
          }
          else{
            $mcoll.ADGroupSTatus = "Added"
            Write-Log -Message "Successfully added $upn to $group" -path $log
          }  
        }
       if($groupoperation -eq "No"){
         $mcoll.ADGroupSTatus = "NA"
       }
      }
      
      $collection+=$mcoll
    }
      
  }


}
$collection | export-csv $Report1 -NoTypeInformation
##############Disable Operation##########################
if($Operation -eq "Disable"){
  Start-ProgressBar -Title "Disable operation selected" -Timer 10
  Write-Log -Message "Disable operation selected" -path $log 
  
  if($users.count -gt "0"){
    $users | ForEach-Object{
      $error.clear()
      $UPN = $_.trim()
      $mcoll = "" | Select UPN, TeamModeStatus, ADGroupSTatus
      $mcoll.UPN = $UPN
      Write-Log -Message "Processing Disable operation on $UPN" -path $log
      Grant-SOLCsTeamsUpgradePolicy -PolicyName Islands -Identity $UPN
      if($error){
        $mcoll.TeamModeStatus = "Error"
        Write-Log -Message "Error Processing Disable operation on $UPN" -path $log

      }
      else{
        $mcoll.TeamModeStatus= "Success"
        Write-Log -Message "Successful Procssing Disable operation on $UPN" -path $log
        if($groupoperation -eq "Yes"){
          Write-Log -Message "Remove user $UPN to $group" -path $log
        
          $getaduser = Get-ADUser -Filter {UserPrincipalName -eq $UPN}
          Remove-ADGroupMember -Identity $group -Members $getaduser.SamAccountName -confirm:$false
          if($error){
            $mcoll.ADGroupSTatus = "Error"
            Write-Log -Message "Error Removing $upn operation on  $group" -path $log
          
          }
          else{
            $mcoll.ADGroupSTatus = "Removed"
            Write-Log -Message "Successfully Removed $upn to $group" -path $log
          } 
        } 
        if($groupoperation -eq "No"){
         $mcoll.ADGroupSTatus = "NA"
       }
      }
      $collection+=$mcoll
    }
  }
}

$collection | export-csv $Report1 -NoTypeInformation
Write-log -Message "Script Finished" -path $log
RemoveSOL
#############################################################################################