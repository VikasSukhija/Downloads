<#	
    .NOTES
    ===========================================================================
    Created on:   	4/15/2020 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	techwizard.cloud
    Filename:     	DLautomationADattributes.ps1
    ===========================================================================
    .DESCRIPTION
    Static Dynamic List based on AD attributes
#>
####################Load All Functions##############################
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

#################Check if logs folder is created##################
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}

$Temppath  = (Get-Location).path + "\Temp" 
$testlogpath = Test-Path -Path $Temppath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating temp folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Temp -Type directory
}

####################Variables/Logs###########################
$log = Write-Log -Name "DLautomationADattributes" -folder "logs" -Ext "log"

$Csvde = (Get-Location).path + "\temp\csvdeexport.csv"
$csvdefilter = "(&(objectClass=user)(objectCategory=person)(|(msExchHomeServerName=*)(msExchRecipientTypeDetails=2147483648))(!msExchHideFromAddressLists=TRUE)(!useraccountcontrol:1.2.840.113556.1.4.803:=2))"

$smtpserver = "smtpserver"
$erroremail = "Reports@labtest.com"
$from = "DoNotReply@labtest.com"
$count = "3000"

$dl1 = "DynamicStaticDL"
$div = "Tech"
$loc = "Galway"
 
########################Start main script##########
Write-Log -Message "Start Script" -path $log
try
{
  Import-Module Activedirectory
  Write-Log -Message "AD Module Loaded" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message "Error loading AD Module Loaded" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error loading AD Module Loaded DLautomationADattributes" -Body $($_.Exception.Message)
  exit
}
##############start Generating CSV Report#############################
Write-Log -Message "Extracting data from..........AD" -path $log
try {CSVDE -f $Csvde  -r  $csvdefilter -l "mail,sAMAccountName,employeeType,extensionattribute3,l"}
catch 
{
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - Export AD CSV DLautomationADattributes" -Body $($_.Exception.Message)
  exit
}

try{$data = Import-Csv $Csvde}
catch 
{
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - Import CSV DLautomationADattributes" -Body $($_.Exception.Message)
  exit
}
#########################Process SG BSN ALL Users###################
Write-Log -Message "Processing ..........$dl1" -path $log
$collusers = @()
Write-Log -Message "Processing.............. CSV" -path $log
$data | ForEach-Object{
  if((($_.EmployeeType -eq "Employee") -or ($_.EmployeeType -eq "Non-Employee")) -and (($_.extensionattribute3.trim() -eq $div) -or ($_.l.trim() -eq $loc))) #condition for creating dymanic DL
  {$collusers += $_.sAMAccountName}
}
Write-Log -Message "Processed.............. CSV" -path $log

$getaddlgroup = Get-ADGroup -id $dl1 -Properties member |
Select-Object -ExpandProperty member |
Get-ADUser |
Select-Object -ExpandProperty samaccountname
Write-Log -Message "Start..........Comparison" -path $log
########################Compare & add Employee################################
$change = Compare-Object -ReferenceObject $collusers -DifferenceObject $getaddlgroup

$Removal = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "=>"} |
Select-Object -ExpandProperty InputObject

$Addition = $change |
Where-Object -FilterScript {$_.SideIndicator -eq "<="} |
Select-Object -ExpandProperty InputObject

$countrem = $Removal.count
$countadd = $Addition.count

Write-Log -Message "Count of removal is $countrem" -path $log
Write-Log -Message "Count of Addition is $countadd" -path $log

if(($Removal.count -gt $count) -or ($Addition.count -gt $count))
{
  Write-Log -Message "Count of is greater than $count" -path $log -Severity Warning
  Write-Log -Message "Script Terminated" -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Count of is greater than $count - DlautomationADattributes" -Body "Count of is greater than $count - DlautomationADattributes"
  break
}
else
{
  Write-Log -Message "Processing --------------- removals" -path $log
  $Removal | ForEach-Object -Process {
    $sam = $_
    Write-Log -Message "Removing $sam from $dl1" -path $log
    Remove-ADGroupMember -Identity $dl1 -Members $sam -Confirm:$false
    if($error)
    {
      Write-Log -Message "$error" -path $log -Severity Error
      $error.clear()
    }
  }
  Write-Log -Message "Processing ---------------- Additions" -path $log
  $Addition| ForEach-Object -Process {
    $sam = $_
    Write-Log -Message "Adding $sam to $dl1" -path $log
    Add-ADGroupMember -Identity $dl1 -Members $sam -Confirm:$false
    if($error)
    {
      Write-Log -Message "$error" -path $log -Severity Error
      $error.clear()
    }
  }
}

Write-Log -Message "Processed ..........$dl1" -path $log

#################################Completed Distribution group code###########

Remove-Item -Path $Csvde 
########################Recycle reports & logs##############################
$path2 = (Get-Location).path + "\Logs\"
	
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path2 |
Where-Object {$_.CreationTime -lt $limit} |
Remove-Item -recurse -Force
	
Get-Date
Write-Log -Message "Script --- Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Transcript Log - DlautomationADattributes" -Body "Transcript Log - DlautomationADattributes" -Attachments $log
  
###########################################################################