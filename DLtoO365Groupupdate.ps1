<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	4/30/2020 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	https://techwizard.cloud/2020/05/11/updated-members-of-office-365-group-based-on-ad-group-or-distribution-list/
    Filename:     	Dlto365Groupupdate.ps1
    ===========================================================================
    .DESCRIPTION
    This will run daily and export the members from dl security group and update o365 group
#>
param (
  [string]$Adgroup =  $(Read-Host "Enter AD Group as Source"),
  [string]$o365group = $(Read-Host "Enter the o365 group as Destination"),
  [string]$Removeanswer = $(Read-Host "If removal of members is required ?, type Yes or No"),
  [string]$user1 = $(Read-Host "Enter the Admin User id to conenct to Exchange Online"),
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

Function LaunchEOL {

  param
  (
    $Credential
  )
	
  $UserCredential = $Credential

  Import-Module ExchangeOnlineManagement -Prefix "EOL" -Verbose
  Connect-ExchangeOnline -Prefix "EOL" -Credential $UserCredential
	
  }
	
  Function RemoveEOL {
	
  $Session = Get-PSSession | where {$_.ComputerName -like "outlook.office365.com"}
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
$log = Write-Log -Name "Groupadd-Log" -folder "logs" -Ext "log"

########################Start Script###################
Write-Log -Message "Start script" -path $log
###########userid & password###########################

$Credential1 = New-Object System.Management.Automation.PSCredential -ArgumentList $User1, $password1

##################Loading modules############################
try{
  Import-module Activedirectory
  LaunchEOL -Credential $Credential1
  Write-Log -Message "Loaded all modules" -path $log
}
catch{
  $exception = $($_.Exception.Message)
  Start-ProgressBar -Title "Error loading Modules and functions" -timer 10
  Write-Log -Message "Loaded all modules" -path $log -Severity Error
  Write-Log -Message "$exception" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured loading Modules - DLtoO365GroupUpdate" -Body $($_.Exception.Message)
  exit 
}

################################Fetch Ad group members#######################
try{

  Write-Log -Message "Start fetching group membership information $ADgroup" -path $log
  $collgroup1 = Get-ADGroup -id $ADgroup -Properties member |
  Select-Object -ExpandProperty member |
  Get-ADUser |
  Select-Object -ExpandProperty UserPrincipalname
  $countmem = $collgroup1.count
  Write-Log -Message "Fetched Groupmembership count = $countmem" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error fetching group membership information $ADgroup" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured fetching group membership information -  DLtoO365GroupUpdate" -Body $($_.Exception.Message)
  exit;

}
################################Fetch o365 group members##########################
try{

  Write-Log -Message "Start fetching o365 group membership information $ADgroup" -path $log
  $collgroup2 = Get-eolUnifiedGroupLinks -LinkType Member -Identity $o365group |
  Select-Object -ExpandProperty PrimarySmtpAddress
  $countmem = $collgroup2.count
  Write-Log -Message "Fetched o365 Groupmembership count = $countmem" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error fetching o365 group membership information $o365group" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured fetching group membership information -  DLtoO365GroupUpdate" -Body $($_.Exception.Message)
  exit;

}
#########################Compare both groups######################
$change = Compare-Object -ReferenceObject $collgroup1 -DifferenceObject $collgroup2

$Addition = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "<="} |
Select-Object -ExpandProperty InputObject

$additioncount = $Addition.count
Write-Log -Message "Count of Addition is $additioncount" -path $log

$Removal = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "=>"} |
Select-Object -ExpandProperty InputObject

$removalcount = $Removal.count
Write-Log -Message "Count of Removal is $removalcount" -path $log

#########################process o365 group addition########################
if(($Removeanswer -eq "No") -or ($Removeanswer -eq "Yes")){
  if($additioncount -lt $countofchanges){
    if($Addition){
      $Addition | ForEach-Object{
        $error.clear()
        $upn = $_
        Write-Log -Message "ADD $upn to $o365group" -path $log
        Add-EOLUnifiedGroupLinks -Identity $o365group -LinkType Members -Links $upn
        if($error){
          Write-Log -Message "error - ADD $upn to $o365group" -path $log -Severity Error
          Write-Log -Message "$error" -path $log
        }
      }
    }
    else{
      Write-Log -Message "Nothing to Process" -path $log
    }
  }

  else{

    Write-Log -Message "ADD count $additioncount is more than $countofchanges" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured ADD count $additioncount  is more than $countofchanges - DLtoO365GroupUpdate" -Body "Error has occured ADD count $additioncount is more than $countofchanges - DLtoO365GroupUpdate"
  }
}

#########################process o365 group removal########################
if($Removeanswer -eq "Yes"){
  if($removalcount -lt $countofchanges){
    if($removal){
      $removal | ForEach-Object{
        $error.clear()
        $upn = $_
        Write-Log -Message "Remove $upn from $o365group" -path $log
        Remove-EOLUnifiedGroupLinks -Identity $o365group -LinkType Members -Links $upn -confirm:$false
                if($error){
          Write-Log -Message "error - ADD $upn to $o365group" -path $log -Severity Error
          Write-Log -Message "$error" -path $log
        }
      }
    }
    else{
      Write-Log -Message "Nothing to Process" -path $log
    }
  }

  else{

    Write-Log -Message "Removal count $removalcount is more than $countofchanges" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured Remove count $removalcount is more than $countofchanges - DLtoO365GroupUpdate" -Body "Error has occured Remove count $removalcount is more than $countofchanges - DLtoO365GroupUpdate"
  }
}
RemoveEOL
########################Recycle reports & logs###############################
$path1 = $logpath
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "DLtoO365GroupUpdate - log" -Body "DLtoO365GroupUpdate -log" -Attachments $log

###############################################################################
