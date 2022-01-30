<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	5/23/2019 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	EOLLicenseCompliancegroupbased.ps1
    ===========================================================================
    .DESCRIPTION
    This script will check the members of the E3 group nad checkl if Exchnage 
    license group is added or not, if not than it will add the EOL License group.
#>
####################Load All Functions##############################
param (
  [string]$Group1 = $(Read-Host "Enter AD group for E3 License"),
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors"),
  [string]$Group2 = $(Read-Host "Enter AD group for E3 EOL License"),
  $count = $(Read-Host "Enter threshold for addition and removal")
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


##########################Load variables & Logs####################

$log = Write-Log -Name "log_EOLE32ADgroup" -folder logs -Ext log

########################mainScript################################
Write-Log -Message "Start Script" -path $log 
Write-Log -Message "E3 O365 group name: $Group1" -path $log 
Write-Log -Message "E3 EOL group name: $Group2" -path $log 
Write-Log -Message "SMTP server: $smtpserver" -path $log 
Write-Log -Message "From Address: $from" -path $log 
Write-Log -Message "Alert Email: $erroremail" -path $log 
Write-Log -Message "Threshhold: $count" -path $log 
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
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error has occured loading AD Module - EOLLicenseCompliancegroupbased" -Body $($_.Exception.Message)
  Exit
}

Write-Log -Message "Start fetching all users from o365 AD E3 $Group1" -path $log
$allo365E3users = Get-ADGroup $Group1 -Properties Member |
Select-Object -Expand Member |
Get-ADUser -Properties msExchRecipientTypeDetails |
where{$_.msExchRecipientTypeDetails  -eq "2147483648"} |
select -ExpandProperty UserPrincipalName
    
Write-Log -Message "Fetched all users from o365 AD E3 $Group1" -path $log
Write-Log -Message "Start fetching all users from o365 EOL $Group2" -path $log
$allo365CurrentEOLLicusers = Get-ADGroup $Group2 -Properties Member |
Select-Object -Expand Member |
Get-ADUser -Properties msExchRecipientTypeDetails |
where{$_.msExchRecipientTypeDetails  -eq "2147483648"} |
select -ExpandProperty UserPrincipalName
    
Write-Log -Message "Fetched all users from o365 EOL $Group2" -path $log

###############Comaore to get adds#######################################
$change = Compare-Object -ReferenceObject $allo365E3users -DifferenceObject $allo365CurrentEOLLicusers 

$Addition = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "<="} |
Select-Object -ExpandProperty InputObject

$additioncount = $Addition.count
Write-Log -Message "Count of Addition is $additioncount" -path $log
if($Addition.count -gt $count)
{
  Write-Log -Message "Count of is greater than $count" -path $log -Severity Warning
  Write-Log -Message "Script Terminated" -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Count of is greater than $count - EOLLicenseCompliancegroupbased" -Body "Count of is greater than $count - EOLLicenseCompliancegroupbased"
  Exit
}
else
{
  Write-Log -Message "Processing ---------------- Additions" -path $log
  $colladditions = @()
  $Addition | ForEach-Object -Process {
    $upn = $_
    Write-Log -Message "Adding $upn to $Group2" -path $log
    $getuser = Get-ADUser -Filter {UserPrincipalName -eq $upn} 
    $colladditions += $getuser.samaccountname
  }
  Write-Log -Message "Collected all Additions" -path $log
  
  $val = 0
  $colladditionscoll = @()
  for($i = 0;$i -lt $colladditions.count)
  {
    While($val -ne "100")
    {
      $colladditionscoll += $colladditions[$val + $i]
      $val++
    }
    if($val -eq "100")
    {
      $val = 0
      $i = $i+100
      $colladditionscoll = $colladditionscoll | where{$_}
      Write-Log -Message "ADD Members ....$colladditionscoll" -path $log
      ADD-ADGroupMember -identity $Group2 -Members $colladditionscoll -Confirm:$false
      $colladditionscoll = @()
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
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Transcript Log - EOLLicenseCompliancegroupbased" -Body "Transcript Log - EOLLicenseCompliancegroupbased" -Attachments $log

##############################################################