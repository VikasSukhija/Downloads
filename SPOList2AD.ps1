<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	9/5/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	api2adspolist.ps1
    ===========================================================================
    .DESCRIPTION
    This will ADD the groupmember by reading spo list
#>
#################logs and variables##########################
$log = Write-Log -Name "api2adspolist" -folder "logs" -Ext "log"

$siteURL = "https://techwizard.sharepoint.com/sites/Automation/"
$lst = "SPO2AD"

$countofchanges = "500"
$BatchSize = "5000"

$logrecyclelimit = "60"

$smtpserver = "smtpserver"
$erroremail = "reports@labtest.com"
$from = "Automated@labtest.com"
########################Start Script################
Write-Log -Message "Start script" -path $log
Write-Log -Message "Get Crendetials for Admin ID" -path $log
if(Test-Path -Path ".\Password.xml"){
  Write-Log -Message "Password file Exists" -path $log
}else{
  Write-Log -Message "Generate password" -path $log
  $Credential = Get-Credential 
  $Credential | Export-Clixml ".\Password.xml"
}
#############################################################
$Credential = $null
$Credential = Import-Clixml ".\Password.xml"
########################################################################
try {
  Write-Log -Message "Start ......... Script" -path $log
  Connect-PnPOnline -Url $siteURL -Credentials $Credential
  Write-Log -message "Loaded All Modules" -Path $log
}
catch {
  $exception = $_.Exception.Message
  Write-Log -Message "exception $exception has occured loading CSOM - api2adspolist" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "CSOM Error - api2adspolist" -Body $($_.Exception.Message)
  break;
}

#####################################Start procesisng List Items############################################
try {  
  $Query = New-Object Microsoft.SharePoint.Client.CamlQuery
  $Query.ViewXml = "<View Scope='RecursiveAll'><Query><OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy></Query><RowLimit Paged='TRUE'>$BatchSize</RowLimit></View>"
  $ListItems = Get-PnPListItem -List $lst  -Query $query.ViewXml
  $listitemcount = $ListItems.count
  Write-Log -message  "count of items - $listitemcount" -path $log

  $collection = @()
  foreach ($listItem in $ListItems) {
    if ($listItem["Status"] -eq "InProgress") {
      $coll = "" | select ID, ADGroup, Action, Member,erroremail
      $ID = $listItem["ID"]
      $ADGroup = $listItem["ADGroup"]
      $Action = $listItem["Action"]
      $Member = $listItem["Member"]
      $eemail = $listItem["erroremail"]
      $coll.ID = $ID
      $coll.ADGroup = $ADGroup
      $coll.Action = $Action
      $coll.Member = $Member
      $coll.erroremail = $eemail
      $collection += $coll
    }
  }
}
catch {
  $exception = $_.Exception.Message
  Write-Log -Message "exception $exception has occured Reading api2adspolist" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "List Reading Error api2adspolist" -Body $($_.Exception.Message)
  Break;
}

$collcount = $collection.count
Write-Log -Message "Collection count $collcount" -path $log
#######################################Process collected requests######################### 
if (($collection.count -lt $countofchanges) -and ($collection.count -gt "0")) {
  $collection | ForEach-Object {
    $error.clear()
    $ADGroup = $ID = $Action = $Member = $null
    $id = $_.ID
    $ADGroup = $_.ADGroup
    $Action = $_.Action
    $Member = $_.Member
    $eemail = $_.erroremail
    if($eemail -eq $null ){$eemail=$erroremail}

    Write-Log -Message "Request - $id" -path $log
    Write-Log -Message "ADGroup - $ADGroup" -path $log
    Write-Log -Message "Action - $Action" -path $log
    Write-Log -Message "Member - $Member" -path $log
    Write-Log -Message "eemail - $eemail" -path $log
    $getaduser = $null
    $getaduser = get-aduser -filter { UserPrincipalName -eq $Member }
    if ($getaduser) {
      Write-Log -Message "Processing - $Action - $Member" -path $log
      #############Check for Action##########################################
      if ($action -eq "ADD") {
        Add-ADGroupMember -Identity $ADGroup -Members $($getaduser.samaccountname)
      }
      if ($action -eq "REMOVE") {
        Remove-ADGroupMember -Identity $ADGroup -Members $($getaduser.samaccountname) -confirm:$false
      }
      
    } 
    ############################Find ADaccount Not Found#########################
    else {
      Write-Log -Message "User Not Found for $Member" -path $log
      Set-PnPListItem -List $lst -Identity $ID -Values @{"Status" = "UserNotFound" }
      Send-MailMessage -SmtpServer $smtpserver -From $from -To $eemail -bcc $erroremail -Subject "Error User Not Found api2adspolist - $id" -Body "User Not Found for $Member"
      
    }
      
    ########################Catch error##########################################
    if ($error) { 
      Set-PnPListItem -List $lst -Identity $ID -Values @{"Status" = "Error" }
      Write-Log -Message "Error - $error" -path $log
      Send-MailMessage -SmtpServer $smtpserver -From $from -To $eemail -bcc $erroremail -Subject "Error has occured api2adspolist - $id" -Body $error[0].tostring()
      $error.clear()
    }
    else {
      Write-Log -Message "Success - $Action - $Member"  -path $log
      Set-PnPListItem -List $lst -Identity $ID -Values @{"Status" = "Completed" }
    }
  }
  ###############################################################################
  Write-Log -Message "Script Finished" -path $log
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - api2adspolist" -Attachments $log
}
elseif ($collection.count -ge $countofchanges) {
  Write-Log -message "Count of changes are more than $countofchanges - Please Check api2adspolist" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Count of changes are more than $countofchanges - Please Check api2adspolist" -Body "Count of changes are more than $countofchanges - Please Check api2adspolist"
}
########################Recycle reports & logs##############
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Disconnect-PnPOnline
#############################completed########################################################