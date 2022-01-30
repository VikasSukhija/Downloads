<#PSScriptInfo

    .VERSION 1.0

    .GUID ad6f9ca1-9de6-4635-9b92-de53a2ab7af9

    .AUTHOR Vikas Sukhija

    .COMPANYNAME techwizard.cloud

    .COPYRIGHT techwizard.cloud

    .TAGS

    .LICENSEURI 

    .PROJECTURI 

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES

    .PRIVATEDATA

    Created with: 	ISE
    Created on:   	8/18/2021 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AzureAdGroupmembershipupdatefromtxt.ps1

#>

<# 

    .DESCRIPTION 
    This script will update azuread group membership

#> 
###############################Paramters#########################################
param (
  [Parameter(Mandatory = $true)]
  [string]$Azgroupid,
  [string]$Userlist = 'Users.txt', #Userprincipalnames
  [Parameter(Mandatory = $true)]
  [ValidateSet('ADD','Remove')]
  $operation
)
################################Load functions#######################################
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
    $null = New-Item -Path (Get-Location).path -Name $foldername -Type directory
  }
}####new folder creation
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

######################logs and variables####################################
$log = Write-Log -Name "AzGroupUpdate" -folder "logs" -Ext "log"
$report1 = Write-Log -Name "AzGroupUpdate" -folder "report" -Ext "csv"

$collection =@()
#############################################################################
Write-log -message "Start.............Script" -path $log
try{
  Connect-AzureAD
  Write-log -message "Connected to AzureAD" -path $log
}
catch{
 $exception = $_.Exception.Message
 Write-Log -Message "exception $exception has occured connecting AzureAD" -path $log -Severity Error
 exit
}
#######################process users#########################################
Get-Content $Userlist | ForEach-Object{
  $error.clear()
  $upn=$_.trim()
  $coll = "" | select UPN, Status
  $coll.UPN = $upn
  $getazureaduser = Get-AzureADUser -Filter "userprincipalname eq '$($upn)'"
  if($getazureaduser){
    $getazmembership = Get-AzureADUserMembership  -ObjectId $getazureaduser.ObjectId -All $true
    ###########################Add Operation############################
    if($operation -eq "ADD"){
      if($getazmembership.objectId -contains $Azgroupid){
        $coll.Status = "AlreadyMember"
        Write-log -message "$UPN is already member of $Azgroupid" -path $log -Severity Warning
      }
      else{
        Add-AzureADGroupMember -ObjectId $Azgroupid -RefObjectId $getazureaduser.ObjectId
        if($error){
          Write-log -message "Error - Adding $UPN to $Azgroupid" -path $log -Severity error
          $coll.Status = "ErrorADD"
          $error.clear()
        }
        else{
          Write-log -message "Success - Adding $UPN to $Azgroupid" -path $log
          $coll.Status = "SuccessADD"
        }
      }
    }
    ###################################Remove Operation##################
    if($operation -eq "Remove"){
      if($getazmembership.objectId -contains $Azgroupid){
        Remove-AzureADGroupMember -ObjectId $Azgroupid -MemberId $getazureaduser.objectid
        if($error){
          Write-log -message "Error - Removing $UPN to $Azgroupid" -path $log -Severity error
          $coll.Status = "ErrorRemove"
          $error.clear()
        }
        else{
          Write-log -message "Success - Remove $UPN to $Azgroupid" -path $log
          $coll.Status = "SuccessRemove"
        }
      }
      else{
        $coll.Status = "NotMember"
        Write-log -message "$UPN is not member of $Azgroupid" -path $log -Severity Warning
      }
    }
  }
  else{
    Write-log -message "$UPN NotFound" -path $log 
    $coll.Status="UserNotFound"
  }
  $collection+=$coll
}

$collection | Export-Csv $report1 -NoTypeInformation
Write-log -message "Finish............Script" -path $log
Disconnect-AzureAD
##########################################################################################