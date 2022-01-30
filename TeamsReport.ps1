<#	
    .NOTES
    ===========================================================================
    Created on:   	4/02/2019 2:26 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	TeamsReport.ps1
    Update:         4/8/2019 (upated password to be used as secure string)
    ===========================================================================
    .DESCRIPTION
    This will report on AL teams across the tenant
    Requires: Latest teams module and Exchaneg online Shell
#>
############Script Parameters##############
param (
  [string]$userId = $(Read-host "Enter UserID"), 
  $password = $(Read-host "Enter Password"-AsSecureString)
)
#############Load Functions#################
$error.clear()
try { $null = Stop-Transcript }
catch { $error.clear() }

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
      $date1 = Get-Date -format d
      $date1 = $date1.ToString().Replace("/", "-")
      $time = Get-Date -format t
	
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
        "Information"{Write-Host $concatmessage -ForegroundColor Green}
        "Warning"{Write-Host $concatmessage -ForegroundColor Yellow}
        "Error"{Write-Host $concatmessage -ForegroundColor Red}
      }
      
      Add-Content -Path $path -Value $concatmessage
    }
  }
}

function LaunchEOL
{
  param
  (
    $cred
  )
	
  $UserCredential = $cred
	
  $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
	
  Import-PSSession $Session -Prefix "EOL" -AllowClobber
}
Function RemoveEOL
{
  $Session = Get-PSSession | where { $_.ComputerName -like "outlook.office365.com" }
  Remove-PSSession $Session
}
##########################Load variables & Logs####################
$log = Write-Log -Name "MSTeamOwnerReport" -folder logs -Ext log
$output1 = Write-Log -Name "MSTeamOwner" -folder Report -Ext html

$smtpserver = "SMTPserver"
$from = "donotreply@labtest.com"
$erroremail = "Reports@labtest.com"
$collection =@()

#####################Create folder and credential from arguments###############
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{New-Item -Path (Get-Location).path -Name Logs -Type directory}

$reportpath = (Get-Location).path + "\Report"
$testReportpath = Test-Path -Path $reportpath
if($testReportpath -eq $false)
{New-Item -Path (Get-Location).path -Name Report -Type directory}

$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $userId, $password
##########Start Script main##############

Write-Log -Message "Script....Started" -path $log
try
{
  Connect-MicrosoftTeams -Credential $Credential
  Write-Log -Message "Connected to teams Module" -path $log
}
catch
{
  $exception = $($_.Exception.Message)
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Connecting MS Team Module MS Team Report" -Body $($_.Exception.Message)
  Write-Log -Message "Exception occured connecting Teams module $exception" -path $log -Severity Error
  Exit
}
try
{
  Write-Host "Connecting to EOL" -ForegroundColor Green
  LaunchEOL -cred $Credential
  Write-Log -Message "Connected to Exchange Online" -path $log
}
catch
{
  $exception = $($_.Exception.Message)
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - EOL Connection MS Team Report" -Body $($_.Exception.Message)
  Write-Log -Message "Exception occured connecting EOL Shell $exception" -path $log -Severity Error
  Exit
}

$collTeam = Get-Team | select DisplayName, GroupId, Description
Write-Log -Message "feteched All Teams" -path $log
Disconnect-MicrosoftTeams
$collUnifiedGroup = get-EOLunifiedgroup -resultsize unlimited | select Name, AccessType, ExternalDirectoryObjectId, WhenCreated, ManagedByDetails, SharePointSiteUrl
Write-Log -Message "feteched All Unified Groups" -path $log
RemoveEOL
Foreach($team in $collTeam)
{
  $mcoll = "" | select Name, Description, GroupId, AccessType, WhenCreated, SharePointSiteUrl, ManagedByDetails
  $teamdispname = $team.DisplayName
  Write-Log -Message "Processing.............$teamdispname" -path $log
  $mcoll.Name = $team.DisplayName
  $mcoll.Description = $team.Description
  $mcoll.GroupId = $team.groupId
  foreach($ugroup in $collUnifiedGroup)
  {
    if($team.GroupId -eq $ugroup.ExternalDirectoryObjectId)
    {
      $mcoll.AccessType = $ugroup.AccessType
      $mcoll.WhenCreated = $ugroup.WhenCreated
      $mcoll.SharePointSiteUrl = $ugroup.SharePointSiteUrl
      $mcoll.ManagedByDetails = $ugroup.ManagedByDetails
    }
  }
  
  $collection += $mcoll
}

############Format HTML###########
$HTMLFormat = "<style>"
$HTMLFormat = $HTMLFormat + "BODY{background-color:GainsBoro;}"
$HTMLFormat = $HTMLFormat + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$HTMLFormat = $HTMLFormat + "TH{border-width: 2px;padding: 0px;border-style: solid;border-color: black;background-color:darksalmon}"
$HTMLFormat = $HTMLFormat + "TD{border-width: 2px;padding: 0px;border-style: solid;border-color: black;background-color:LightBlue}"
$HTMLFormat = $HTMLFormat + "</style>"
################################
$count = $collection.count
$privateteams = $collection | where{$_.AccessType -eq "Private"}
$publicteams = $collection | where{$_.AccessType -eq "Public"}
$privateteamscount = $privateteams.count
$publicteamscount = $publicteams.count

Write-Log -Message "Converting to HTML" -path $log
$collection |
ConvertTo-Html -Head $HTMLFormat -Body "<H2><Font Size = 4,Color = DarkCyan>Microsoft Teams = $count, Private Teams = $privateteamscount, Public Teams = $publicteamscount  </Font></H2>" -AS Table |
Set-Content $output1

Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "MS Team Report" -Body "MS Team Report" -Attachments $output1
Write-Log -Message "Report Sent to $erroremail" -path $log
########################Recycle reports & logs##############
$path1 = (Get-Location).path + "\report"
$path2 = (Get-Location).path + "\Logs"
$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force

Get-ChildItem -Path $path2 |
Where-Object -FilterScript {$_.CreationTime -lt $limit} |
Remove-Item -Recurse -Force
Write-Log -Message "Script....Finished" -path $log
##############################################################################