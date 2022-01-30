<#PSScriptInfo

.VERSION 1.1

.GUID aa46f8a4-3d0f-4eda-b157-7e99eb5f4057

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard

.COPYRIGHT Vikas Sukhija

.TAGS

.LICENSEURI

.PROJECTURI http://techwizard.cloud/2020/08/17/intune-check-particular-app-installation-on-devices

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
http://techwizard.cloud/2020/08/17/intune-check-particular-app-installation-on-devices

.PRIVATEDATA
Update: 8/27/2020 fixe dteh bug of folder creation
Update: 10/18/2021 Get-IntuneManagedDevice | Get-MSGraphAllPages stopped working so change to pagination
update: 12/2/2021 changed to filter as MS has made a change in API
#>

<# 

.DESCRIPTION 
 Find and report particular application installed on devices 

#> 
param (
  [Parameter(Mandatory = $true)]
  [string]$Application
  )

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

####################Load variables and log####################
$log = Write-Log -Name "IntuneDeviceApplication-Log" -folder "logs" -Ext "log"
$Report = Write-Log -Name "IntuneDeviceApplication-Report" -folder "Report" -Ext "csv"
$collection = @()
$graphApiVersion = "beta"
################connect to modules###################
Write-Log -Message "Start............Script" -path $log
try
{
  Connect-MSGraph
  Write-Log -Message "Intune Module Loaded" -path $log
}
catch
{
  $exception = $_.Exception
  Write-Log -Message "Error loading AD/Intune Module Loaded" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Exit
}

##########process devicess with compliant state as unknown####
try
{
  Write-Log -Message "Start fetching all devices in the enviornment, it could take a while" -path $log 
  $getalldevices = Get-IntuneManagedDevice -Filter "managementagent eq 'mdm'" | Get-MSGraphAllPages 
  Write-Log -Message "Count of devices $($getalldevices.count)" -path $log 
}
catch
{
  $exception = $_.Exception
  Write-Log -Message "Error occured fetching unkown devices" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Exit
}
###########Remove these devices from Intune#################
$count=0
$getalldevices |
ForEach-Object{
  $mcoll = "" |
  Select-Object id, deviceName, AppName, Appversion, Appid, SizeinByte, enrolledDateTime, lastSyncDateTime, emailAddress, serialNumber, complianceState
  $mcoll.id = $_.id
  $deviceid = $_.id
  $Resource = "deviceManagement/managedDevices" + "/" + "$deviceid" + "?`$expand=detectedApps"
  $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
  $app = Invoke-MSGraphRequest -HttpMethod GET -Url $uri
  $foundApp = $app.detectedApps |
  Where-Object{$_.displayname -like $Application}
  $mcoll.appname = $foundApp.displayname
  $mcoll.Appversion = $foundApp.Version
  $mcoll.SizeInByte = $foundApp.SizeInByte
  $mcoll.Appid = $foundApp.id
  $mcoll.deviceName = $_.deviceName
  $mcoll.enrolledDateTime = $_.enrolledDateTime
  $mcoll.lastSyncDateTime = $_.lastSyncDateTime
  $mcoll.emailAddress = $_.emailAddress
  $mcoll.serialNumber = $_.serialNumber
  $mcoll.complianceState = $_.complianceState
  $collection += $mcoll
  $count=$count+1
  if($_.deviceName){
    Write-Progress -Activity "Finding $Application" -status "$($_.deviceName)" -percentComplete ($count/$getalldevices.count*100)
  }else{
   Write-Progress -Activity "Finding $Application" -status "Device Not Found" -percentComplete ($count/$getalldevices.count*100)
  }
}
$collection | where{$_.appname -like $Application} | Export-Csv $Report -NoTypeInformation
 
Write-Log -Message "Script Finished" -path $log
################################################################################