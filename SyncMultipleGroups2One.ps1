<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	2/5/2021 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	TechWizard.cloud
    Project URL:    https://techwizard.cloud/2021/02/07/sync-multiple-groups-to-single-group/
    Filename:     	SyncmultipleGroupsWithOne.ps1
    ===========================================================================
    .DESCRIPTION
    This scirpt will sync multiple groups and consolidate it into one group
#>
param (
  [string[]]$groups = $(Read-Host "Enter Groups as Source seprated by Coma"),
  [string]$Desgroup = $(Read-Host "Enter the Destination Group"),
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors"),
  $countofchanges = $(Read-Host "Enter Count of changes"),
  $logrecyclelimit = $(Read-Host "Enter Number of Days for log Recycling")
)
######################Load Functions############################################
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

Function Get-ADGroupMembersRecursive{
  Param(
    [Parameter(Mandatory = $true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [String[]]$Groups,
    [ValidateNotNullOrEmpty()]
    [String[]]$Properties
  )
  Begin{
    $Results = @()
    [String[]]$defaultproperties = "distinguishedName","name","objectClass","objectGUID","SamAccountName","SID"
    $Properties+=$defaultproperties
    $Properties = $Properties | Sort-Object -Unique
  }
  Process{
    ForEach($adobj in $Groups){
      $getgroupdn =  (Get-ADGroup -identity $adobj).DistinguishedName
      $findallgroups = Get-ADGroup -identity $getgroupdn -Properties members| Select-Object -ExpandProperty members | get-adobject | Where-Object{$_.objectClass -eq "Group"} |Select DistinguishedName
      $Results+=$getgroupdn
      ForEach($Object in $findallgroups){
        Get-ADGroupMembersRecursive $Object.DistinguishedName -Properties $Properties
      }
    }
  }
  End{
    $Results = $Results | Select-Object -Unique
    $collgroupmembers=@()
    foreach($item in $Results){
      $arrgroupmembers =@()
      $arrgroupmembers = Get-ADGroup -id $item -Properties members | Select-Object -ExpandProperty members |get-adobject | Where-Object{$_.objectClass -eq "user"} | Get-ADUser -properties $Properties | Select-Object $Properties
      $collgroupmembers+=$arrgroupmembers
    }
    $collgroupmembers
  }
} #Get-ADGroupMembersRecursive

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
#####################Finished Loading Functions##################################
####################Load variables and log#######################################
$log = Write-Log -Name "GroupSync-Log" -folder "logs" -Ext "log"
########################Start Script################
Write-Log -Message "Start script" -path $log
try 
{
  Import-Module ActiveDirectory
  Write-Log -Message "loaded.... AD Module" -path $log
}
catch 
{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD Module" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured loading AD Module - SyncmultipleGroupsWithOne" -Body $($_.Exception.Message)
  exit;
}

try{
  $groups = $groups -split ","
  $collgroup=@()
  Write-Log -Message "Start fetching group membership information $groups" -path $log
  $collgroup1 = Get-ADGroupMembersRecursive -groups $groups  | Select-Object -ExpandProperty samaccountname
  $collgroup = $collgroup1 | select -Unique
  Write-Log -Message "Start fetching group membership information $Desgroup" -path $log
  $collgroup3 = Get-ADGroup -id $Desgroup -Properties member | Select-Object -ExpandProperty member | Get-ADUser | Select-Object -ExpandProperty samaccountname #destination group
  Write-Log -Message "Finished fetching group membership" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error fetching group membership information" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured fetching group membership information - SyncmultipleGroupsWithOne" -Body $($_.Exception.Message)
  exit;
}

try{
  Write-Log -Message "Start comparing $groups with $Desgroup" -path $log
  $changes = Compare-Object -ReferenceObject $collgroup -DifferenceObject $collgroup3 | 
  Select-Object -Property inputobject, @{
    n = 'State'
    e = {If ($_.SideIndicator -eq "=>"){"Removal" } Else { "Addition" }}
  }
  if($Changes){
    $removal = $Changes | Where-Object -FilterScript {$_.State -eq "Removal"} | Select -ExpandProperty inputobject
    $Addition = $Changes | Where-Object -FilterScript {$_.State -eq "Addition"} | Select -ExpandProperty inputobject
      
    if($Addition){
      $addcount = $Addition.count
      Write-Log -Message "Adding members to $Desgroup count $addcount" -path $log
      if($addcount -le $countofchanges){
        $Addition | ForEach-Object{
          $amem = $_
          Write-Log -Message "ADD  $amem  to $Desgroup" -path $log
          ADD-ADGroupMember -identity $Desgroup -Members $amem -Confirm:$false
        }
      }else{
        Write-Log -Message "ADD count $addcount is more than $countofchanges" -path $log -Severity Error
        Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured ADD count $addcount is more than $countofchanges - SyncmultipleGroupsWithOne" -Body "Error has occured ADD count $addcount is more than $countofchanges - SyncmultipleGroupsWithOne"
         }
        }
    if($removal){
          $remcount = $removal.count
          Write-Log -Message "Removing members from $Desgroup count $remcount" -path $log
          if($remcount -le $countofchanges){
            $removal | ForEach-Object{
              $rmem = $_
              Write-Log -Message "Remove $rmem from $Desgroup" -path $log
              Remove-ADGroupMember -identity $Desgroup -Members $rmem -Confirm:$false
            }     
          }else{
            Write-Log -Message "Remove count $remcount is more than $countofchanges" -path $log -Severity Error
           Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured Remove count $remcount is more than $countofchanges - SyncmultipleGroupsWithOne" -Body "Error has occured Remove count $remcount is more than $countofchanges - SyncmultipleGroupsWithOne"   
          } 
        }
      }  
 
   }
   catch{
     $exception = $_.Exception
     Write-Log -Message "Error comparing $Desgroup with$groups" -path $log -Severity Error 
     Write-Log -Message $exception -path $log -Severity error
     Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured comparing $Desgroup - SyncmultipleGroupsWithOne" -Body $($_.Exception.Message)
   }
   
########################Recycle reports & logs##############
Write-Log -Message "Recycle Logs" -path $log -Severity Information
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false

Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - SyncmultipleGroupsWithOne" -Body "Log - SyncmultipleGroupsWithOne" -Attachments $log

##############################################################################