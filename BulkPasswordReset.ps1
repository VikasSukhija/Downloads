<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	11/19/2019 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	BulkPasswordReset.ps1
    ===========================================================================
    .DESCRIPTION
    This will reset the password for BUlk sam accountnames
#>
param (
  [string]$Password = $(Read-Host "Enter Password that will be Set"),
  [string]$Userlist = $(Read-Host "Enter Text file with Network accounts")

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

$Reportpath  = (Get-Location).path + "\Report" 
$testlogpath = Test-Path -Path $Reportpath 
if($testlogpath -eq $false)
{
  ProgressBar -Title "Creating Report folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Report -Type directory
}


####################Load variables and log#######################
$log = Write-Log -Name "BulkPasswordReset-Log" -folder "logs" -Ext "log"
$Report = Write-Log -Name "BulkPasswordReset-Report" -folder "Report" -Ext "csv"

$users = Get-Content $Userlist
$collection = @()
Write-Log -Message "Start Script" -path $log

########################Load Modules#############################
try{
  Import-Module ActiveDirectory
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD Module Loaded" -path $log -Severity Error
  Write-Log -Message $exception -path $log -Severity error
  ProgressBar -Title "Error loading AD Module Loaded - EXIT" -Timer 10
  Exit
}

########################Process users#############################
$SecurePassword=ConvertTo-SecureString $Password –asplaintext –force


$users | ForEach-Object{
  $error.clear()
  $mcoll = "" | Select UserID, PasswordReset
  $user = $_.trim()
  $mcoll.UserID = $user
  Write-Log -Message "Processing..............$user" -path $log
  Set-ADAccountPassword -Identity $user -Reset -NewPassword $SecurePassword
  Set-ADUser -Identity $user -ChangePasswordAtLogon $false
  if($error){
    Write-Log -Message "Password reset Failure $user " -path $log -Severity Error
    $mcoll.PasswordReset = "Error"
    $error.clear()
    
  }
  else{
    $mcoll.PasswordReset = "Success"
    Write-Log -Message "Password reset Success $user " -path $log
  }
  

  $collection+=$mcoll
}
$collection | Export-Csv $Report -NoTypeInformation
Write-Log -Message "Finish Script" -path $log

###########################################################################