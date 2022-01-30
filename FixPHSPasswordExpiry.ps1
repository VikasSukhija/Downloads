<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	2/9/2021
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	FixPHSPasswordExpiry.ps1
    ===========================================================================
    .DESCRIPTION
    This Script get the user whose password has expired and will push o365 to force password change
    It can be scheduled to run daily.
#>
#####################################################
param (
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors"),
  $countofchanges = "20",
  $logrecyclelimit = "60"
)

###################Functions#########################
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
} #New-FolderCreation
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
function Set-Recyclelogs
{
  [CmdletBinding(
      SupportsShouldProcess = $true,
  ConfirmImpact = 'High')]
  param
  (
    [Parameter(Mandatory = $true,ParameterSetName = 'Local')]
    [string]$foldername,
    [Parameter(Mandatory = $true,ParameterSetName = 'Local')]
    [Parameter(Mandatory = $true,ParameterSetName = 'Path')]
    [Parameter(Mandatory = $true,ParameterSetName = 'Remote')]
    [int]$limit,
    
    [Parameter(ParameterSetName = 'Local',Position = 0)][switch]$local,
    
    [Parameter(Mandatory = $true,ParameterSetName = 'Remote')]
    [string]$ComputerName,
    [Parameter(Mandatory = $true,ParameterSetName = 'Remote')]
    [string]$DriveName,
    [Parameter(Mandatory = $true,ParameterSetName = 'Remote')]
    [string]$folderpath,
    
    [Parameter(ParameterSetName = 'Remote',Position = 0)][switch]$Remote,
    
    [Parameter(Mandatory = $true,ParameterSetName = 'Path')]
    [ValidateScript({
          if(-Not ($_ | Test-Path) ){throw "File or folder does not exist"}
          return $true 
    })]
    [string]$folderlocation,
    
    [Parameter(ParameterSetName = 'Path',Position = 0)][switch]$Path
    
  )
  
  switch ($PsCmdlet.ParameterSetName) {
    "Local"
    {
      $path1 = (Get-Location).path + "\" + "$foldername"
      if ($PsCmdlet.ShouldProcess($path1 , "Delete")) 
      {
        Write-Host "Path Recycle - $path1 Limit - $limit" -ForegroundColor Green 
        $limit1 = (Get-Date).AddDays(-"$limit") #for report recycling
        $getitems = Get-ChildItem -Path $path1 -recurse -file | Where-Object {$_.CreationTime -lt $limit1} 
        ForEach($item in $getitems){
          Write-Verbose -Message "Deleting item $($item.FullName)"
          Remove-Item $item.FullName -Force 
        }
      }
    }
    "Remote"
    {
      $path1 = "\\" + $ComputerName + "\" + $DriveName + "$" + "\" + $folderpath
      if ($PsCmdlet.ShouldProcess($path1 , "Delete")) 
      {
        Write-Host "Recycle Path - $path1 Limit - $limit" -ForegroundColor Green 
        $limit1 = (Get-Date).AddDays(-"$limit") #for report recycling
        $getitems = Get-ChildItem -Path $path1 -recurse -file | Where-Object {$_.CreationTime -lt $limit1} 
        ForEach($item in $getitems){
          Write-Verbose -Message "Deleting item $($item.FullName)"
          Remove-Item $item.FullName -Force 
        }
      }
    }
    
    "Path"
    {
      $path1 = $folderlocation
      if ($PsCmdlet.ShouldProcess($path1 , "Delete")) 
      {
        Write-Host "Path Recycle - $path1 Limit - $limit" -ForegroundColor Green 
        $limit1 = (Get-Date).AddDays(-"$limit") #for report recycling
        $getitems = Get-ChildItem -Path $path1 -recurse -file | Where-Object {$_.CreationTime -lt $limit1} 
        ForEach($item in $getitems){
          Write-Verbose -Message "Deleting item $($item.FullName)"
          Remove-Item $item.FullName -Force 
        }
      }
    }
  }
  
}# Set-Recycle logs
function LaunchMSOL {

  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $false)]
    $Credential
  )
  import-module msonline
  Write-Host "Enter MS Online Credentials" -ForegroundColor Green
  Connect-MsolService -Credential $Credential
} #LaunchMSOL
	
#####################Load variables and log###############
$log = Write-Log -Name "FixPHSPasswordExpiry-Log" -folder "logs" -Ext "log"
$ObjFilter = "(&(objectClass=user)(objectCategory=person)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))"
##################get-credentials##########################
Write-Log -Message "Get Crendetials for Admin ID for MSOnline Connection" -path $log
if(Test-Path -Path ".\Password.xml"){
  Write-Log -Message "Password file Exists" -path $log
}else{
  Write-Log -Message "Generate password" -path $log
  $Credential = Get-Credential 
  $Credential | Export-Clixml ".\Password.xml"
}
#############################################################
$Credential = $null
$Credential = Import-Clixml ".\Password.xml"

########################Start Script#########################
Write-Log -Message "Start....................Script" -path $log
$collusers = @()

try{
  Write-Log -Message "Fetch all Enabled Users with Password Expiry Status True" -path $log
  $collusers = Get-ADUser -LDAPFilter $ObjFilter -properties passwordexpired | Select DistinguishedName, SamAccountName, PasswordExpired, UserPrincipalName
  $collusers = $collusers.where{($_.passwordexpired -eq $true)}
  Write-Log -Message "Fetched users that have password Expiry status is True" -path $log
}
catch{
  $exception = $_.Exception.Message
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error -FixPHSPasswordExpiry" -Body $($_.Exception.Message)
  exit
}

if(($collusers.count -le $countofchanges) -and ($collusers.count -gt 0)){
try{
    LaunchMSOL -Credential $Credential
    Connect-AzureAD -Credential $Credential
    foreach($user in $collusers){
      $upn = $user.UserPrincipalName
      $sam = $user.SamAccountName
      $msoluser = Get-MsolUser -UserPrincipalName $upn
      if($msoluser){
        $azureaduser = Get-AzureADUser -ObjectId $msoluser.objectid
        if($azureaduser.PasswordProfile.ForceChangePasswordNextLogin -eq $true){
          Write-Log -Message "Force Change password is already set for $upn - $sam" -path $log
        }
        else{
           Write-Log -Message "Setting force change password for $upn - $sam" -path $log
           Set-MsolUserPassword -UserPrincipalName $upn -ForceChangePassword:$true -ForceChangePasswordOnly:$true
        }
      }
      else{
        Write-Log -Message "$upn - $sam not found" -path $log
      }
    }
    Disconnect-AzureAD
  }
  catch{
    $exception = $_.Exception.Message
    Write-Log -Message $exception -path $log -Severity error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - FixPHSPasswordExpiry" -Body $($_.Exception.Message)
    exit
  }

}
elseif($collusers.count -gt $countofchanges)
{
  Write-Log -Message "Exiting Script as Count of changes exceeded $($collusers.count) more than $countofchanges" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Exiting Script as Count of changes exceeded FixPHSPasswordExpiry" -Body "Exiting Script as Count of changes exceeded $($collusers.count) more than $countofchanges"
  Exit
}
########################Recycle reports & logs#############################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -confirm:$false
Write-Log -Message "Script............Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - FixPHSPasswordExpiry" -Body "Log - FixPHSPasswordExpiry" -Attachments $log
  
###########################################################################
