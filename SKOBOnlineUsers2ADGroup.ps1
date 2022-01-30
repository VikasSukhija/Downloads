
<#PSScriptInfo

.VERSION 1.0

.GUID fcba9d8a-0507-4349-9201-406707c5cdad

.AUTHOR Vikas Sukhija

.COMPANYNAME http://SysCloudPro.com

.COPYRIGHT http://SysCloudPro.com

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS


.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
 https://syscloudpro.com/2019/04/23/add-all-skype-for-business-online-users-to-ad-group/

Required modules:

Skype Module
Activedirectory Module

.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 This script will add all SKOB users to AD group
Documentation:  https://syscloudpro.com/2019/04/23/add-all-skype-for-business-online-users-to-ad-group/
#> 
param (
  [string]$Group = $(Read-host "Enter AD group"),
  [string]$smtpserver = $(Read-host "Enter SMTP Server"),
  [string]$from = $(Read-host "Enter From Address"),
  [string]$erroremail = $(Read-host "Enter Address for Report and Errors"),
  $count = $(Read-host "Enter threshold for addition and removal")
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
    "Create"{
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
    "Message"{
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


##########################Load variables & Logs####################

$log = Write-Log -Name "log_SKOBONline2ADgroup" -folder logs -Ext log

$group 
$smtpserver
$from
$erroremail
$count

########################mainScript################################
Write-Log -Message "Start Script" -path $log 
try{
  Import-Module -Name activedirectory
  Write-Log -Message "AD Module Loaded" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD Module Loaded" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error has occured loading AD Module - SKOBOnlineUsers2ADGroup" -Body $($_.Exception.Message)
  Exit
}

$Allskobonlineusers = Get-CsUser -Filter {HostingProvider -eq "sipfed.online.lync.com"} | Select -ExpandProperty UserPrincipalName
Write-Log -Message "Fetched all SKOB users" -path $log 

  $allUPN = Get-ADGroup  $group -Properties Member | 
  Select-Object -ExpandProperty Member |
  Get-ADUser |
  Select-Object -ExpandProperty UserPrincipalName
  Write-Log -Message "Fetched all UPN from $group" -path $log

###############Comaore to get adds/removes########################
$change = Compare-Object -ReferenceObject $Allskobonlineusers -DifferenceObject $allUPN 

$Removal = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "=>"} |
Select-Object -ExpandProperty InputObject

$Addition = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "<="} |
Select-Object -ExpandProperty InputObject

$removalcount = $Removal.count
$additioncount = $Addition.count
Write-Log -Message "Count of removal is $removalcount" -path $log
Write-Log -Message "Count of Addition is $additioncount" -path $log

if(($Removal.count -gt $count) -or ($Addition.count -gt $count)){
  Write-Log -Message "Count of is greater than $count" -path $log -Severity Warning
  Write-Log -Message "Script Terminated" -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Count of is greater than $count - SKOBOnlineUsers2ADGroup" -Body "Count of is greater than $count - SKOBOnlineUsers2ADGroup"
  break
}
else
{
  Write-Log -Message "Processing --------------- removals" -path $log
  $collremoves=@()
  $Removal | ForEach-Object -Process {
    $upn = $_
    Write-Log -Message "Removing $upn from $group" -path $log
    $getuser = Get-ADUser -Filter {UserPrincipalName -eq $upn} 
    $collremoves+=$getuser.samaccountname
    }
  Write-Log -Message "Collected all Removals" -path $log
  
  $val=0
  $collremovescoll = @()
  for($i=0;$i -lt $collremoves.count){
    While($val -ne "100"){
      $collremovescoll+=$collremoves[$val + $i]
      $val++
    }
    if($val -eq "100"){
      $val=0
      $i=$i+100
      $collremovescoll = $collremovescoll | where{$_}
      Write-Log -Message "Remove Members ....$collremovescoll" -path $log
        Remove-ADGroupMember -identity $group -Members $collremovescoll -Confirm:$false
        $collremovescoll=@()
    }
  }
  
  
  Write-Log -Message "Processing ---------------- Additions" -path $log
  $colladditions=@()
  $Addition | ForEach-Object -Process {
    $upn = $_
    Write-Log -Message "Adding $upn to $group" -path $log
    $getuser = Get-ADUser -Filter {UserPrincipalName -eq $upn} 
    $colladditions+=$getuser.samaccountname
    }
  Write-Log -Message "Collected all Additions" -path $log
  
  $val=0
  $colladditionscoll = @()
  for($i=0;$i -lt $colladditions.count){
    While($val -ne "100"){
      $colladditionscoll+=$colladditions[$val + $i]
      $val++
    }
    if($val -eq "100"){
      $val=0
      $i=$i+100
      $colladditionscoll = $colladditionscoll | where{$_}
        Write-Log -Message "ADD Members ....$colladditionscoll" -path $log
        ADD-ADGroupMember -identity $group -Members $colladditionscoll -Confirm:$false
        $colladditionscoll=@()
    }
  }
}

########################Recycle reports & logs##############
$path1 = $logpath
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Transcript Log - SKOBOnlineUsers2ADGroup" -Body "Transcript Log - SKOBOnlineUsers2ADGroup" -Attachments $log

##############################################################


