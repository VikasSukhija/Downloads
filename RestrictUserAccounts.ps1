<#PSScriptInfo

    .VERSION 1.0

    .GUID cc1197a7-88f1-4411-9161-f952f390a949

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
    Created on:   	6/14/2021 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	RestrictUserAccounts.ps1

#>

<# 

    .DESCRIPTION 
    This script will restrict the accounts in OU with List of computers

#> 

###############################Paramters#########################################
param (
  [string]$OU = 'OU=Lab,OU=PTU,OU=WVD,OU=InfrastructureServices,DC=lab,DC=labtest,DC=com',
  [string]$Machinelist = 'machines.txt',
  [Parameter(Mandatory = $true)]
  [ValidateSet('RestrictionADD','RestrictionRemove','UnRestrict')]
  $operation
)
$error.clear()
##############################Functions##########################################
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
####################Load variables and log#######################################
$log = Write-Log -Name "RestrictMFGAccounts-Log" -folder "logs" -Ext "log"
$machinefile = (get-location).Path  + "\" + $Machinelist

Write-Log -Message "Start ................Script" -path $log
Write-Log -Message "Check Machine Sanity" -path $log
$collmachines = @()
get-content $machinefile | ForEach-Object{
  $machine = $_.trim()
  $getmachine=$null
  $getmachine = Get-ADComputer -Identity $machine -ea silentlycontinue
  if($getmachine){
    Write-Log -Message "Found - $machine" -path $log
    $collmachines += $machine
  }else{
    $collmachines += $machine
  }
}
$error.clear()
#################################################################################
Write-Log -Message "Fetched all Computers from the file" -path $log
[string]$LogonWorkstations = $collmachines -join ","
Write-Log -Message "WS from File - $LogonWorkstations" -path $log
Write-Log -Message "Fetch all Users accounts from $OU" -path $log
$getadusers = get-aduser -SearchBase $OU -filter * | Select -ExpandProperty samaccountname
Write-Log -Message "Start restricting the accounts" -path $log
if($operation -eq 'RestrictionADD'){
  $getadusers | ForEach-Object{
    $samname = $_
    try{
      $getexistingws =  (Get-ADUser -Identity $samname -Properties LogonWorkstations).LogonWorkstations
      if($getexistingws){
        $LogonWorkstations = $LogonWorkstations + "," + $getexistingws
        Write-log -message "existiingLogonWS - $getexistingws" -path $log
        Write-log -message "Select Unique values of machines" -path $log
        $arrlogonws = $LogonWorkstations -split ","
        $LogonWorkstations = ($arrlogonws | Select -Unique) -join ","
        Write-log -message "FinalWS - $LogonWorkstations" -path $log
      }
      Write-Log -Message "$samname - Set logon workstations to $LogonWorkstations" -path $log
      Set-ADUser -Identity $samname -LogonWorkstations $LogonWorkstations
    }
    catch{
      $exception = $_.Exception.Message
      Write-Log -Message "$samname - exception $exception has occured" -path $log -Severity Error
    }
  }
}
if($operation -eq 'RestrictionRemove'){
  $getadusers | ForEach-Object{
    $samname = $_
    try{
      $getexistingws =  (Get-ADUser -Identity $samname -Properties LogonWorkstations).LogonWorkstations
      if($getexistingws){
        Write-log -message "existiingLogonWS - $getexistingws" -path $log
        $arrexistingWS = $getexistingws -split ","
        $compare = Compare-Object -ReferenceObject $arrexistingWS -DifferenceObject $collmachines -IncludeEqual
        $CollectWS = $compare | where{$_.SideIndicator -eq '<='} | Select -ExpandProperty InputObject
        [string]$LogonWorkstations = $CollectWS  -join ","
        Write-log -message "FinalWS - $LogonWorkstations" -path $log
        if($LogonWorkstations){
          Write-Log -Message "$samname - Set logon workstations to $LogonWorkstations" -path $log
          Set-ADUser -Identity $samname -LogonWorkstations $LogonWorkstations
        }else{
          Write-Log -Message "$samname - Set logon workstations to Null" -path $log
          Set-ADUser -Identity $samname -LogonWorkstations $null
        }
        }
     
    }
    catch{
      $exception = $_.Exception.Message
      Write-Log -Message "$samname - exception $exception has occured" -path $log -Severity Error
    }
  }
}
if($operation -eq 'UnRestrict'){
  $getadusers | ForEach-Object{
    $samname = $_
    try{
      $getexistingws =  (Get-ADUser -Identity $samname -Properties LogonWorkstations).LogonWorkstations
      if($getexistingws){
        Write-log -message "existiingLogonWS - $getexistingws" -path $log
        }
      Write-Log -Message "$samname - Set logon workstations to Null" -path $log
      Set-ADUser -Identity $samname -LogonWorkstations $null
    }
    catch{
      $exception = $_.Exception.Message
      Write-Log -Message "$samname - exception $exception has occured" -path $log -Severity Error
    }
  }
}
Write-Log -Message "Accounts restricted/Unrestricted - check for errors in the logs, if there are errors - reprocess after fixing" -path $log
Write-Log -Message "Script Finished" -path $log
########################################################################
