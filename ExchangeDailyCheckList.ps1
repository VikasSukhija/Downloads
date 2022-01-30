<#PSScriptInfo

.VERSION 2.0

.GUID d898fc0f-63ad-4d28-98e9-3579b6dd9475

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard.cloud

.COPYRIGHT TechWizard.cloud

.TAGS

.LICENSEURI

.PROJECTURI https://techwizard.cloud/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
https://techwizard.cloud

.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Exchange Health Check - Tested on 2016 
#############################################################################
#       Author: Mahesh Sharma /Vikas Sukhija  
#       Reviewer: Vikas SUkhija      
#       Date: 06/10/2013
#	      Modified:06/19/2013 - made it to run from any path
#       Modified:02/09/2014 - started modifying it for exchange 2010
#       Modified:02/18/2014 - modified to include all mailox servers in test mailflow
#       Modified:05/22/2014 - added activation prefrence
#	      Modified:09/09/2014 - included DAG DB backups status
#	      Modified:04/15/2015 - updated for Exchange 2013
#	      Modified:07/12/2015 - Updated to show yellow indicators if queue length increases 50
#       Modified:08/28/2020 - Updated for 2016, Alert Yes No, Parameterized
#       Modified:09/02/2020 - Updated to add alerts aon queues and added indicators
#       Description: Exchange Health Status
#############################################################################
#> 

param (
  [Parameter(Mandatory = $true, HelpMessage = "Please Enter Exchange Server FQDN")]
  [string]$Exserver,
  [Parameter(Mandatory = $true, HelpMessage = "Please Enter SMTP Relay Server")]
  [string]$smtpserver,
  [Parameter(Mandatory = $true, HelpMessage = "Please Enter From Address")]
  [string]$from,
  [Parameter(Mandatory = $true, HelpMessage = "Add receipient email address")]
  [String[]]$to,
  [Parameter(Mandatory = $true, HelpMessage = "Enter Report or Alert")]
  [ValidateSet('Report','Alert')]
  [string]$Action,
  [Parameter(Mandatory = $false)]
  [int]$logrecyclelimit = "60",
  [Parameter(Mandatory = $false)]
  [int]$backupmonitorhours = "24",
  [Parameter(Mandatory = $false)]
  [int]$QueueMonitor = "100"
)
###########################Functions##########################################
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

#################connect exchange###########################################
$psurl = "http://" + $Exserver + "/" + "PowerShell" 
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $psurl -Authentication Kerberos 
Import-PSSession $Session -AllowClobber

###########################Define Variables#################################
$report = Write-Log -Name 2016Report -Ext htm -folder report
$hrs = (Get-Date).Addhours(-$backupmonitorhours) 

###############################HTml Report Content##########################
Add-Content $report "<html>" 
Add-Content $report "<head>" 
Add-Content $report "<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>" 
Add-Content $report '<title>Exchange Status Report</title>' 
Add-Content $report '<STYLE TYPE="text/css">' 
Add-Content $report  "<!--" 
Add-Content $report  "td {" 
Add-Content $report  "font-family: Tahoma;" 
Add-Content $report  "font-size: 11px;" 
Add-Content $report  "border-top: 1px solid #999999;" 
Add-Content $report  "border-right: 1px solid #999999;" 
Add-Content $report  "border-bottom: 1px solid #999999;" 
Add-Content $report  "border-left: 1px solid #999999;" 
Add-Content $report  "padding-top: 0px;" 
Add-Content $report  "padding-right: 0px;" 
Add-Content $report  "padding-bottom: 0px;" 
Add-Content $report  "padding-left: 0px;" 
Add-Content $report  "}" 
Add-Content $report  "body {" 
Add-Content $report  "margin-left: 5px;" 
Add-Content $report  "margin-top: 5px;" 
Add-Content $report  "margin-right: 0px;" 
Add-Content $report  "margin-bottom: 10px;" 
Add-Content $report  "" 
Add-Content $report  "table {" 
Add-Content $report  "border: thin solid #000000;" 
Add-Content $report  "}" 
Add-Content $report  "-->" 
Add-Content $report  "</style>" 
Add-Content $report "</head>" 
Add-Content $report "<body>" 
Add-Content $report  "<table width='100%'>" 
Add-Content $report  "<tr bgcolor='Lavender'>" 
Add-Content $report  "<td colspan='7' height='25' align='center'>" 
Add-Content $report  "<font face='tahoma' color='#003399' size='4'><strong>DAG Active Manager</strong></font>" 
Add-Content $report  "</td>" 
Add-Content $report  "</tr>" 
Add-Content $report  "</table>" 
 
Add-Content $report  "<table width='100%'>" 
Add-Content $report  "<tr bgcolor='IndianRed'>" 
Add-Content $report  "<td width='10%' align='center'><B>Identity</B></td>" 
Add-Content $report  "<td width='5%' align='center'><B>PrimaryActiveManager</B></td>" 
Add-Content $report  "<td width='20%' align='center'><B>OperationalMachines</B></td>" 
 

Add-Content $report "</tr>" 

##############################Get ALL DAG's##################################

$inputdag = @()

$indag = Get-DatabaseAvailabilityGroup 

foreach($dg in $indag)
{
  $mem = $dg.Servers
  foreach($m in $mem)
  {
    if((Get-ExchangeServer $m.Name).AdminDisplayVersion -like "*15.1*"){$inputdag += $dg.Name}
  }
}

$inputdag = $inputdag | Select-Object -uniq

########################################################################################################
########################################################################################################

$dagList = $inputdag
$TestMailFlow = Get-ExchangeServer | Where-Object{$_.ServerRole -like "*Mailbox*"}

########################################################################################################
##############################################Check PAM#################################################

foreach ($dag in $dagList) 
{
  $FullStatus = Get-DatabaseAvailabilityGroup -Status $dag

  Foreach ($status in $FullStatus)
  {
    $Identity = $status.identity
    $PrimaryActiveManager = $status.PrimaryActiveManager
    $Servers = $status.Servers
    Add-Content $report "<tr>" 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B> $Identity</B></td>" 
    Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B>$PrimaryActiveManager</B></td>" 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$Servers</B></td>" 
    Add-Content $report "</tr>"
  }
}

##################################################################################################################
############################################## Mailbox Database Status ###########################################

Add-Content $report  "<tr bgcolor='Lavender'>" 
Add-Content $report  "<td colspan='7' height='25' align='center'>" 
Add-Content $report  "<font face='tahoma' color='#003399' size='4'><strong>Mailbox Database Status</strong></font>" 
Add-Content $report  "</td>" 
Add-Content $report  "</tr>"

Add-Content $report  "</tr>" 
Add-Content $report  "</table>" 
Add-Content $report  "<table width='100%'>" 
Add-Content $report "<tr bgcolor='IndianRed'>"
Add-Content $report  "<td width='25%' align='center'><B>databaseName</B></td>" 
Add-Content $report "<td width='25%' align='center'><B>Status</B></td>" 
Add-Content $report "<td width='25%' align='center'><B>ActiveCopy</B></td>" 
Add-Content $report  "<td width='25%' align='center'><B>CopyQueuelength</B></td>" 
Add-Content $report  "<td width='25%' align='center'><B>ReplayQueueLength</B></td>" 
Add-Content $report  "<td width='25%' align='center'><B>LastInspectedLogTime</B></td>" 
Add-Content $report  "<td width='25%' align='center'><B>ContentIndexState</B></td>" 
Add-Content $report "</tr>" 


$mbxdb = Get-MailboxDatabase | Get-MailboxDatabaseCopyStatus 

$mbxdb = $mbxdb | Sort-Object Status -Descending


foreach ($db in $mbxdb)
{
  $dbname = $db.name
  foreach($dbn in $dbname)
  {
    $stcopy = Get-MailboxDatabaseCopyStatus $dbn
    $acpref = $stcopy.ActivationPreference
  }

  $server = $db.Mailboxserver
  $status = $db.Status
  $ActiveCopy = $db.ActiveCopy
  $CopyQueuelength = $db.CopyQueuelength
  $ReplayQueueLength = $db.ReplayQueueLength
  $LastInspectedLogTime = $db.LastInspectedLogTime
  $ContentIndexState = $db.ContentIndexState

  Add-Content $report "<tr>" 
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$dbname</B></td>" 

  if ((($status -eq "Mounted") -and ($acpref -eq 1)) -or ($status -eq "Healthy"))
  {Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B>$status</B></td>"}
  
  elseif((($status -eq "Mounted") -and ($acpref -ne 1)) -or ($status -eq "Healthy"))
  {Add-Content $report "<td bgcolor= 'yellow' align=center>  <B>$status</B></td>"}
        
  else
  {
    Add-Content $report "<td bgcolor= 'Red' align=center>  <B>$status</B></td>"
    if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $server $dbname status $status"}
  }
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$ActiveCopy</B></td>" 
  if ($CopyQueuelength -le "50")

  {Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B>$CopyQueuelength</B></td>"}
  else
  {Add-Content $report "<td bgcolor= 'Yellow' align=center>  <B>$CopyQueuelength</B></td>"
    if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $server $dbname Copy Queue $CopyQueuelength"}
  }

  if ($ReplayQueueLength -le "50")

  {Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B>$ReplayQueueLength</B></td>"}
  else
  {Add-Content $report "<td bgcolor= 'Yellow' align=center>  <B>$ReplayQueueLength</B></td>"
    if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $server $dbname Replay Queue $ReplayQueueLength"}
  }
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$LastInspectedLogTime</B></td>" 

  if ($ContentIndexState -eq "Healthy")

  {Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B>$ContentIndexState</B></td>"}
  else
  {Add-Content $report "<td bgcolor= 'Red' align=center>  <B>$ContentIndexState</B></td>"
    if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $server $dbname Index $ContentIndexState"}
  }

  Add-Content $report "</tr>"
}

#################################################################################################################
##############################################DAG DB Backup Status###############################################

Add-Content $report  "<tr bgcolor='Lavender'>" 
Add-Content $report  "<td colspan='7' height='25' align='center'>" 
Add-Content $report  "<font face='tahoma' color='#003399' size='4'><strong>DAG Database Backup Status</strong></font>" 
Add-Content $report  "</td>" 
Add-Content $report  "</tr>"

Add-Content $report  "</tr>" 
Add-Content $report  "</table>" 
Add-Content $report  "<table width='100%'>" 
Add-Content $report "<tr bgcolor='IndianRed'>"
Add-Content $report  "<td width='10%' align='center'><B>Database</B></td>" 
Add-Content $report  "<td width='5%' align='center'><B>BackupInProgress</B></td>" 
Add-Content $report  "<td width='10%' align='center'><B>SnapshotLastFullBackup</B></td>" 
Add-Content $report  "<td width='5%' align='center'><B>SnapshotLastCopyBackup</B></td>" 
Add-Content $report  "<td width='10%' align='center'><B>LastFullBackup</B></td>" 
Add-Content $report  "<td width='5%' align='center'><B>RetainDeletedItemsUntilBackup</B></td>"

Add-Content $report "</tr>" 

$dbst = Get-MailboxDatabase | Where-Object{$_.MasterType -like "DatabaseAvailabilityGroup"}

$dbst | ForEach-Object{
  $st = Get-MailboxDatabase $_.Name -status
  $dbname = $st.Name
  $dbbkprg = $st.BackupInProgress
  $dbsnpl = $st.SnapshotLastFullBackup
  $dbsnplc = $st.SnapshotLastCopyBackup
  $dblfb = $st.LastFullBackup
  $dbrd = $st.RetainDeletedItemsUntilBackup
  Add-Content $report "<tr>" 
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$dbname</B></td>" 
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$dbbkprg</B></td>" 
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$dbsnpl</B></td>" 
  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$dbsnplc</B></td>" 
  if($dblfb -lt $hrs)
  {Add-Content $report "<td bgcolor= 'Red' align=center>  <B>$dblfb</B></td>"
    if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $dbname Backup Unhealthy"}
  }
  else
  {Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B>$dblfb</B></td>"}    	

  Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$dbrd</B></td>" 
  Add-Content $report "</tr>"
}


##################################################################################################################
############################################## Test mail Flow For DAG ############################################
Add-Content $report  "<tr bgcolor='Lavender'>" 
Add-Content $report  "<td colspan='7' height='25' align='center'>" 
Add-Content $report  "<font face='tahoma' color='#003399' size='4'><strong>Mail Flow Test Report</strong></font>" 
Add-Content $report  "</td>" 
Add-Content $report  "</tr>"

Add-Content $report  "</tr>" 
Add-Content $report  "</table>" 
Add-Content $report  "<table width='100%'>" 
Add-Content $report "<tr bgcolor='IndianRed'>"
Add-Content $report  "<td width='25%' align='center'><B>Server</B></td>" 
Add-Content $report  "<td width='25%' align='center'><B>Result</B></td>" 
Add-Content $report "<td width='25%' align='center'><B>Message Latency Time</B></td>" 
Add-Content $report  "<td width='25%' align='center'><B>IsRemoteTest</B></td>" 
Add-Content $report "</tr>" 


Foreach ($server in $TestMailFlow)
{
  $server = $server.Name
  Write-Host "Test Mail flow...$server"

  $url = "http://" + $server + "/" + "Powershell"
  $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $url

  $flow = Invoke-Command -Session $Session {Test-Mailflow}
  #test-mailflow $server

  if($flow -ne $null)
  {
    $result = $flow.TestMailflowResult
    $time = $flow.MessageLatencyTime
    $remote = $flow.IsRemoteTest
    Add-Content $report "<tr>" 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$server</B></td>" 
    if ($result -eq "Success")
    {Add-Content $report "<td bgcolor= 'Aquamarine' align=center>  <B> $result</B></td>"}
    else
    {Add-Content $report "<td bgcolor= 'Red' align=center>  <B> $result</B></td>"
      if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $server MailFlow Test failed"}
    } 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$time</B></td>" 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$remote</B></td>" 

    Add-Content $report "</tr>"
  }
  
}

##################################################################################################################
############################################## Get Queue For HUB Servers ############################################
  
  Add-Content $report  "<tr bgcolor='Lavender'>" 
  Add-Content $report  "<td colspan='7' height='25' align='center'>" 
  Add-Content $report  "<font face='tahoma' color='#003399' size='4'><strong>Mail Queue Status</strong></font>" 
  Add-Content $report  "</td>" 
  Add-Content $report  "</tr>"

  Add-Content $report  "</tr>" 
  Add-Content $report  "</table>" 
  Add-Content $report  "<table width='100%'>" 
  Add-Content $report "<tr bgcolor='IndianRed'>"
  Add-Content $report  "<td width='10%' align='center'><B>Identity</B></td>" 
  Add-Content $report "<td width='10%' align='center'><B>Delivery Type</B></td>" 
  Add-Content $report  "<td width='5%' align='center'><B>Status</B></td>" 
  Add-Content $report "<td width='5%' align='center'><B>Message Count</B></td>" 
  Add-Content $report  "<td width='10%' align='center'><B>Next Hop Domain</B></td>"
  Add-Content $report "</tr>" 

  $GetHub = Get-TransportService
  
  foreach ($hub in  $GetHub){

  $server = $hub.Name

  Write-Host "Get Queue...$server"

  $url = "http://" + $server + "/" + "Powershell"
  $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $url

  $queues = Invoke-Command -Session $Session {get-queue}
  foreach ($queue in $queues){ 
    $Identity = $Queue.Identity
    $DeliveryType = $Queue.DeliveryType
    $status = $Queue.Status
    $MSgCount = $Queue.Messagecount
    $NextHopDomain = $Queue.NextHopDomain


    Add-Content $report "<tr>" 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B> $Identity</B></td>" 
    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$DeliveryType</B></td>"
    if(($DeliveryType -notlike "*Shadow*") -and ($MSgCount -gt $QueueMonitor)){ 

      Add-Content $report "<td bgcolor= 'yellow' align=center>  <B>$status</B></td>"
      Add-Content $report "<td bgcolor= 'yellow' align=center>  <B>$MSgCount</B></td>" 
      if($Action -eq "Alert") { Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Open Critical - $Identity Count is $MSgCount"}

    }else{
      Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$status</B></td>"
      Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$MSgCount</B></td>" 
    }

    Add-Content $report "<td bgcolor= 'GainsBoro' align=center>  <B>$NextHopDomain</B></td>" 
  }
  Add-Content $report "</tr>"

  }
################################################################################################################## 

Get-PSSession | where{$_.ConfigurationName -eq "Microsoft.Exchange"} | Remove-PSSession
###########################################################################################################################
######################################################### Send Mail #######################################################


Add-Content $report  "</table>" 
Add-Content $report "</body>" 
Add-Content $report "</html>"

if($Action -eq "Report"){
  $body = Get-Content $report
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Exchange Status Check Report" -Body ($body|out-string) -BodyAsHtml
}

###################################################Exchange Test Complete##################################################