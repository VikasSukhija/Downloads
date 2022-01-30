<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	5/18/2020 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	https://techwizard.cloud/  https://syscloudpro.com/
    Filename:     	TeamOnlyBasedonADGroup.ps1
    ===========================================================================
    .DESCRIPTION
    This will run daily and if any user found without Teamsonly mode, it will upgrade the policy.
#>
param (
  [string]$Adgroup =  $(Read-Host "Enter AD Group as Source"),
  [string]$Domain =  $(Read-Host "Enter onmicrosoft domain"),
  [string]$user1 = $(Read-Host "Enter the Admin User id to conenct to SKOBOnline"),
  $password1 = $(Read-Host "Enter the passwrod" -AsSecureString),
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
function start-ProgressBar
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
#################Check if logs folder is created####
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
####################Load variables and log##########
$log = Write-Log -Name "Teamsonlymode-Log" -folder "logs" -Ext "log"

########################Start Script###################
Write-Log -Message "Start script" -path $log
###########userid & password#############
$Credential1 = New-Object System.Management.Automation.PSCredential -ArgumentList $User1, $password1

##################Loading modules############################
try{
  Import-module Activedirectory
  LaunchSOL -Domain $Domain -allowclobber -UserCredential $Credential1
  Write-Log -Message "Loaded all modules" -path $log
}
catch{
  $exception = $($_.Exception.Message)
  Start-ProgressBar -Title "Error loading Modules and functions" -timer 10
  Write-Log -Message "Loaded all modules" -path $log -Severity Error
  Write-Log -Message "$exception" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured loading Modules - TeamsOnlyBasedonADGroup" -Body $($_.Exception.Message)
  exit 
}
#########Fetch Ad group members that are not teamsonly###########

try{
  Write-Log -Message "Start fetching group membership information $ADgroup" -path $log
  $collADgroup = Get-ADGroup $Adgroup -Properties members | select -ExpandProperty members | Get-ADUser | select -ExpandProperty userprincipalname | Get-SOLCsOnlineUser | Select userprincipalname,TeamsUpgradeEffectiveMode,TeamsUpgradePolicy
  $collnotteamonlymode = $collADgroup | where{$_.TeamsUpgradeEffectiveMode -ne "TeamsOnly"} | select -ExpandProperty userprincipalname
  $countmem = $collnotteamonlymode.count
  Write-Log -Message "Fetched Groupmembership that are not Teamsonly count = $countmem" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error fetching group membership information $ADgroup" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured fetching group membership information -  TeamsOnlyBasedonADGroup" -Body $($_.Exception.Message)
  exit;

}
if(($countmem -lt $countofchanges) -and ($countmem -gt "0")) {
$collnotteamonlymode | ForEach-Object{
  $upn = $_
  try{
    Write-Log -Message "Turning Teams Only Mode ON for $upn" -path $log
    Grant-SOLCsTeamsUpgradePolicy -PolicyName UpgradeToTeams -Identity $upn
  }
  catch{
  $exception = $_.Exception
  Write-Log -Message "Error converting $UPN to TeamsOnly" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error converting $UPN to TeamsOnly -  TeamsOnlyBasedonADGroup" -Body $($_.Exception.Message)
  }
}

}
elseif ($countmem -ge $countofchanges) 
  {
    Write-Host "Number of Teams Only Mode request are more than $countofchanges - TeamsOnlyBasedonADGroup" -ForegroundColor Yellow
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Number of Teams Only Mode request are more than $countofchanges - TeamsOnlyBasedonADGroup"
  }
 RemoveSOL
########################Recycle reports & logs###############################
$path1 = $logpath
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "TeamsOnlyBasedonADGroup - log" -Body "TeamsOnlyBasedonADGroup -log" -Attachments $log

###############################################################################