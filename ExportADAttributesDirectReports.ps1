<#PSScriptInfo

.VERSION 1.0

.GUID eaacbf4c-d41c-49a7-b4bb-166895b55190

.AUTHOR Vikas Sukhija

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://techwizard.cloud/2020/02/18/export-direct-reports-attributes-under-from-list-of-managers/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES https://techwizard.cloud/2020/02/18/export-direct-reports-attributes-under-from-list-of-managers/


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 This will export direct reports attributes of specified networkids
#>

#> 

param (
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
#################Check if logs folder is created##################
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}

$Reportpath  = (Get-Location).path + "\Report" 
$testlogpath = Test-Path -Path $Reportpath 
if($testlogpath -eq $false)
{
  start-ProgressBar -Title "Creating Report folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Report -Type directory
}


####################Load variables and log#######################
$log = Write-Log -Name "DirecrReports-Log" -folder "logs" -Ext "log"
$Report = Write-Log -Name "Directreports-Report" -folder "Report" -Ext "csv"

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
$users | ForEach-Object{
  $error.clear()
  
  $user = $_.trim()
  
  Write-Log -Message "Processing..............$user" -path $log
  $directrports = Get-ADUser -id $user -Properties directreports | Select -ExpandProperty directreports
  $directrports | ForEach-Object{
    $mcoll = "" | Select Manager,FirstName, LastName, EmailAddress,Department, Location, Employeeid
    $mcoll.Manager = $user
    $userid = get-aduser -id $_ -properties mail,department,l,Employeeid
    $mcoll.FirstName = $userid.GivenName
    $mcoll.LastName = $userid.SurName
    $mcoll.EmailAddress = $userid.mail
    $mcoll.Department = $userid.Department
    $mcoll.Location = $userid.L
    $mcoll.Employeeid = $userid.Employeeid
    $collection+=$mcoll
    Write-Log -Message "$mcoll" -path $log
  }
  
}
$collection | Export-Csv $Report -NoTypeInformation
Write-Log -Message "Finish Script" -path $log

###########################################################################