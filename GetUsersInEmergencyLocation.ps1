<#	
    .NOTES
    ===========================================================================
    Created on:   	11/23/2020 9:16 PM
    Created by:   	Vikas Sukhija
    Organization: 	TechWizard.cloud
    Filename:       GetUsersInEmergencyLocation.ps1
    ===========================================================================
    .DESCRIPTION
    Extract Teams users in emegency Location
    https://techwizard.cloud/2020/11/25/teams-exporting-users-in-emergency-location/
#>
###########################################################################
param (
  [string]$locationid = $(Read-Host "Enter the locationsID"),
  [string]$CivicAddressId = $(Read-Host "Enter the Civic AdressID"),
  [string]$domain = $(Read-Host "Enter the onmicrosoft domain")
)
function LaunchSOL
{
  param
  (
    [Parameter(Mandatory = $true)]
    $Domain,
    [Parameter(Mandatory = $false)]
    $Credential
  )
  Write-Host -Object "Enter Skype Online Credentials" -ForegroundColor Green
  $dommicrosoft = $domain + ".onmicrosoft.com"
  $CSSession = New-CsOnlineSession -Credential $Credential -OverrideAdminDomain $dommicrosoft 
  Import-Module (Import-PSSession -Session $CSSession -AllowClobber) -Prefix SOL  -Global
} #Function LaunchSOL

Function RemoveSOL
{
  $Session = Get-PSSession | Where-Object -FilterScript { $_.ComputerName -like "*.online.lync.com" }
  Remove-PSSession $Session
} #Function RemoveSOL

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
#################Logs and reports###########################
$log = Write-Log -Name "GetUsersInEmergencyLocation-Log" -folder "logs" -Ext "log"
$Report = Write-Log -Name "GetUsersInEmergencyLocation-Report" -folder "Report" -Ext "csv"

################connect to SOl###############################
try 
{
  LaunchSOL -Domain $domain
  Write-log -message "loaded.... SKOB Online Module" -path $log
}
catch 
{
  $exception = $_.Exception
  Write-Log -Message "Error loading Module" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  exit;
}
##################################################################
Write-log -message "loaded all users with locationID: $locationid and CivicAddressID:$CivicAddressId" -path $log
$users = Get-SOLCsOnlineVoiceUser -LocationId $locationid  -CivicAddressId $CivicAddressId
Write-log -message "loaded users $($users.count)" -path $log
$collection =@()
foreach($u in $users){
  $mcoll = "" | Select-Object Name, userprincipalName, locationid, CivicAddressId, Number 
  $csuser = get-solcsonlineuser -identity $u.id | Select-Object userprincipalname
  $mcoll.Name = $u.name
  $mcoll.userprincipalName = $csuser.userprincipalname
  $mcoll.locationid = $locationid 
  $mcoll.CivicAddressId = $CivicAddressId
  $mcoll.Number = $u.Number
  $collection+=$mcoll
  Write-log -message "exporting..........$($csuser.userprincipalname)" -path $log
}
Write-log -message "export to CSV file" -path $log
$collection | Export-Csv $report -NoTypeInformation
Write-log -message "Removing SKOB Online Shell" -path $log
RemoveSOL
#################################################################
