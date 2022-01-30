<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	1/12/2021
    Created by:   	Vikas Sukhija
    Organization:   TechWizard.cloud
    Project:	      https://techwizard.cloud/2021/01/24/distribution-group-based-on-head-of-organization/
    Filename:     	DynamicDLBasedonHead.ps1
    Code Credits:   https://lazywinadmin.com/2014/10/powershell-who-reports-to-whom-active.html
    ===========================================================================
    .DESCRIPTION
    This Script get input of Head and DL name to Poplulate
#>

param (
  [string]$Head = $(Read-Host "Enter SamAccountName for Head"),
  [string]$ADgroup = $(Read-Host "Enter the Distribution Group Name to Populate"),
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors"),
  $countofchanges = $(Read-Host "Enter Count of changes")
)
###################Functions for the script##########
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
#####################Load variables and log##########
$log = Write-Log -Name "DynamicDLBasedonHead-Log" -folder "logs" -Ext "log"
$logrecyclelimit = "60"
###########Direct reports Recursive Function#########
function Get-ADdirectReports
{
    PARAM ($SamAccountName)
    Get-Aduser -identity $SamAccountName -Properties directreports | ForEach-Object -Process {
        $_.directreports | ForEach-Object -Process {
            # Output the current Object information
            Get-ADUser -identity $Psitem -Properties mail,manager | Select-Object -Property Name, SamAccountName, Mail, @{ L = "Manager"; E = { (Get-Aduser -iden $psitem.manager).samaccountname } }
            # Find the DirectReports of the current item ($PSItem / $_)
            Get-ADdirectReports -SamAccountName $PSItem
        }
    }
}
########################Start Script##############################
Write-Log -Message "Processing ..........$ADgroup" -path $log
Write-Log -Message "Head - $Head" -path $log

$collusers = @()

try{
  Write-Log -Message "Processing..............subordinates recusrsively" -path $log
  $collusers+=Get-ADdirectReports -SamAccountName $Head | Select-Object -ExpandProperty samaccountname
  Write-Log -Message "Processed.............. all subordinates" -path $log
  Write-Log -Message "Fetching members.............. $ADgroup" -path $log
  $getaddlgroup = Get-ADGroup -id $ADgroup -Properties member |
  Select-Object -ExpandProperty member |
  Get-ADUser |
  Select-Object -ExpandProperty samaccountname
  Write-Log -Message "Fetched members.............. $ADgroup" -path $log
  Write-Log -Message "Start..........Comparison" -path $log
  $change = Compare-Object -ReferenceObject $collusers -DifferenceObject $getaddlgroup
}
catch{
  $exception = $_.Exception.Message
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - DynamicStaticListbasedOnCC" -Body $($_.Exception.Message)
  break
}
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

if(($Removal.count -gt $countofchanges) -or ($Addition.count -gt $countofchanges))
{
  Write-Log -Message "Count of is greater than $countofchanges" -path $log -Severity Warning
  Write-Log -Message "Script Terminated" -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Count of is greater than $countofchanges - DynamicDLBasedonHead" -Body "Count of is greater than $countofchanges - DynamicDLBasedonHead"
  break
}
else
{
  Write-Log -Message "Processing --------------- removals" -path $log
  $Removal | ForEach-Object -Process {
    $sam = $_
    Write-Log -Message "Removing $sam from $ADgroup" -path $log
    Remove-ADGroupMember -Identity $ADgroup -Members $sam -Confirm:$false
    if($error)
    {
      Write-Log -Message "$error" -path $log -Severity Error
      $error.clear()
    }
  }
  Write-Log -Message "Processing ---------------- Additions" -path $log
  $Addition| ForEach-Object -Process {
    $sam = $_
    Write-Log -Message "Adding $sam to $ADgroup" -path $log
    Add-ADGroupMember -Identity $ADgroup -Members $sam -Confirm:$false
    if($error)
    {
      Write-Log -Message "$error" -path $log -Severity Error
      $error.clear()
    }
  }
}

Write-Log -Message "Processed ..........$ADgroup" -path $log
########################Recycle reports & logs##############################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -confirm:$false
Write-Log -Message "Script --- Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - DynamicDLBasedonHead" -Body "Transcript Log - DynamicDLBasedonHead" -Attachments $log
  
###########################################################################
