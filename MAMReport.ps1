<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	10/14/2019 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	MAMREport.ps1
    ===========================================================================
    .DESCRIPTION
    This will extract MAM Report from INtune
#>
 Param(
 [Parameter(Mandatory = $true, HelpMessage="Enter App Identifier, for example: outlook")]
 [ValidateNotNullorEmpty()]
 [string] $appidentifier
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
}

#################Check if logs folder is created####
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
$Reportpath  = (Get-Location).path + "\Report" 
$testlogpath = Test-Path -Path $Reportpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating Report folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Report -Type directory
}
####################Load variables and log####################
$log = Write-Log -Name "MAM-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "MAM-Report" -folder "Report" -Ext "csv"
Write-log -Message "Start.......Script" -path $log

$Resource = "deviceAppManagement/managedAppRegistrations"
$graphApiVersion = "beta"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
 
###################Connect to Intune##########################

try{
 Write-log -Message "Connect to Intune" -path $log
 Connect-MSGraph
 Write-log -Message "Connect to AzureAD" -path $log
 Connect-AzureAD
}
catch{
  $exception = $_.Exception
  Write-Log -Message "Error loading Modules" -path $log -Severity Error 
  Write-Log -Message "$exception" -path $log -Severity Error 
  Start-ProgressBar -Title "exiting script Error loading Modules" -Timer 10
  exit
}

Write-log -Message "Invoke Graph request" -path $log
$Response = Invoke-MSGraphRequest -HttpMethod GET -Url $uri  -Verbose
$getmam = $Response.value | where{$_.appIdentifier -like "*$appidentifier*"}

$NextLink = $Response."@odata.nextLink"
$count=0
while ($NextLink -ne $null){
  $count = $count + 1
  $Response = (Invoke-MSGraphRequest -HttpMethod GET -Url $NextLink  -Verbose)
  Write-log -Message "Processing Page .....$count" -path $log
  $NextLink = $Response."@odata.nextLink"
  $getmam += $Response.value | where{$_.appIdentifier -like "*$appidentifier*"}

}

$allmam = $getmam | Select userId,deviceType,deviceTag,deviceName,createdDateTime,lastSyncDateTime,applicationVersion,appIdentifier

$collection=@()
$allmam | foreach-object{

  $mcoll= "" | Select userId,deviceType,deviceTag,deviceName,createdDateTime,lastSyncDateTime,applicationVersion,appIdentifier
  $getuser = Get-AzureADuser -ObjectId $_.userid
  $userid = $getuser.userprincipalname
  $mcoll.userid = $getuser.userprincipalname
  $mcoll.deviceType = $_.deviceType
  $mcoll.deviceTag = $_.deviceTag
  $mcoll.deviceName = $_.deviceName
  $mcoll.createdDateTime = $_.createdDateTime
  $mcoll.lastSyncDateTime = $_.lastSyncDateTime
  $mcoll.applicationVersion = $_.applicationVersion
  $mcoll.appIdentifier = $_.appIdentifier
  $collection+=$mcoll
  Write-log -Message "Processing..............$userid " -path $log
}

Write-log -Message "Export........Report" -path $log
$collection | Export-Csv $Report1 -NoTypeInformation
Write-log -Message "Finish.......Script" -path $log
#################################################

