<#PSScriptInfo

    .VERSION 1.0

    .GUID a46e2b7e-3b01-4720-9216-b2e212c5c286

    .AUTHOR Vikas Sukhija

    .COMPANYNAME TechWizard.cloud

    .COPYRIGHT Vikas Sukhija

    .TAGS

    .LICENSEURI https://techwizard.cloud/

    .PROJECTURI https://techwizard.cloud/

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES 

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES https://techwizard.cloud/


    .PRIVATEDATA
    ===========================================================================
    Created with: 	ISE
    Created on:   	12/07/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	SyncCSV2SpoList.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This Script will sync CSV to Sharepoint List

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "SyncCSV2SpoList" -folder "logs" -Ext "log"

$siteURL = "https://techwizard.sharepoint.com/sites/ITA/Master/"
$lst = "SPOList"

$sffolderpath = "C:\temp\SyncCSV2SpoList.csv"

$countofchanges = "50"
$BatchSize = "5000"

$logrecyclelimit = "60"
$smtpserver = "SMTPServer.labtest.com"
$erroremail = "Errors@labtest.com"
$from = "DoNotReply@labtest.com"
#################get-credentials##########################
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
##################Connect to Azure####################
########################################################################
try
  {
    Write-Log -Message "Start ......... Script" -path $log
    Connect-PnPOnline -Url $siteURL -Credentials $Credential
    Write-Log -message "Loaded All Modules" -Path $log
  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured loading CSOM - SyncCSV2SpoList" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "CSOM Error - SyncCSV2SpoList" -Body $($_.Exception.Message)
    break;
  }
###################Get List Items##################################
  try
  {  
    $Query = New-Object Microsoft.SharePoint.Client.CamlQuery
    $Query.ViewXml = "<View Scope='RecursiveAll'><Query><OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy></Query><RowLimit Paged='TRUE'>$BatchSize</RowLimit></View>"
    $ListItems = Get-PnPListItem -List $lst  -Query $query.ViewXml
    $listitemcount = $ListItems.count
    Write-Log -message  "count of items - $listitemcount" -path $log

    $collection = @()
    foreach ($listItem in $ListItems)
    {
        $coll = "" | select-object ID,Application,Businessowner,Businessowneremail,BackupBusinessOwner,BackupBusinessOwneremail,Server,BackupITOwner,BackupITOwneremail,ITApplicationowner,ITApplicationowneremail,Businesscriticality,Environment
        $ID = $listItem["ID"]
        $coll.ID = $ID
        $coll.Application = $listItem["Application"]
        $coll.Businessowner = $listItem["Businessowner"]
        $coll.Businessowneremail = $listItem["Businessowneremail"]
        $coll.BackupBusinessOwner = $listItem["BackupBusinessOwner"]
        $coll.BackupBusinessOwneremail = $listItem["BackupBusinessOwneremail"]
        $coll.Server = $listItem["Server"]
        $coll.BackupITOwner = $listItem["BackupITOwner"]
        $coll.BackupITOwneremail = $listItem["BackupITOwneremail"]
        $coll.ITApplicationowner = $listItem["ITApplicationowner"]
        $coll.ITApplicationowneremail = $listItem["ITApplicationowneremail"]
        $coll.Businesscriticality = $listItem["Businesscriticality"]
        $coll.Environment = $listItem["Environment"]
        $collection += $coll

    }
  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured Reading SyncCSV2SpoList" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "List Reading Error SyncCSV2SpoList" -Body $($_.Exception.Message)
    Break;
  }

  $collcount = $collection.count
  Write-Log -Message "Collection count $collcount" -path $log
  #######################################Now Collect the Costcenters from SF file and compare###############
  $collection1 = $collection | Sort-Object Application | Select Application,Businessowner,Businessowneremail,BackupBusinessOwner,BackupBusinessOwneremail,Server,BackupITOwner,BackupITOwneremail,ITApplicationowner,ITApplicationowneremail,Businesscriticality,Environment
  $data = Import-Csv $sffolderpath
  $data = $data | Sort-Object Application
  Write-Log -message "count from csv $($data.Application.count)" -path $log
  $compare = Compare-Object -ReferenceObject $data -DifferenceObject $collection1
  $addition = $compare | where {$_.SideIndicator -eq "<="}
  $removal = $compare | where {$_.SideIndicator -eq "=>"}
 
  Write-Log -Message "Count of additions $($addition.Application.count)" -path $log
  Write-Log -Message "Count of removals $($removal.Application.count)" -path $log

  if(($addition.Application.count -gt 0) -and ($addition.Application.count -lt $countofchanges)){
    foreach($item in $addition){
      $item = Add-PnPListItem -List $lst -Values @{"Application" = $item.Application;"Businessowner" = $item.Businessowner;"Businessowneremail" = $item.Businessowneremail;"BackupBusinessOwner" = $item.BackupBusinessOwner;"BackupBusinessOwneremail" = $item.BackupBusinessOwneremail;"Server" = $item.Server;"BackupITOwner" = $item.BackupITOwner;"BackupITOwneremail" = $item.BackupITOwneremail;"ITApplicationowner" = $item.ITApplicationowner;"ITApplicationowneremail" = $item.ITApplicationowneremail;"Businesscriticality" = $item.Businesscriticality;"Environment" = $item.Environment}
      Write-Log -Message "Added - $($item.ID)" -path $log
    }
  }
  elseif ($addition.Application.count -ge $countofchanges) 
  {
    Write-Log -message "Count of changes $($addition.Application.count) are more than $countofchanges - Please Check SyncCSV2SpoList" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Count of changes are more than $countofchanges - Please Check SyncCSV2SpoList" -Body "Count of changes are more than $countofchanges - Please Check SyncCSV2SpoList"
  }
  ######################Now remove item from Spo Slist##########################
  if(($removal.Application.count -gt 0) -and ($removal.Application.count -lt $countofchanges)){

    foreach($item in $removal){
      $collectionid = $collection | where {$_.Application -eq $item.Application -and $_.Businessowner -eq $item.Businessowner -and $_.Businessowneremail -eq $item.Businessowneremail -and $_.BackupBusinessOwner -eq $item.BackupBusinessOwner -and $_.BackupBusinessOwneremail -eq $item.BackupBusinessOwneremail -and $_.Server -eq $item.Server -and $_.BackupITOwner -eq $item.BackupITOwner -and $_.BackupITOwneremail -eq $item.BackupITOwneremail -and $_.ITApplicationowner -eq $item.ITApplicationowner -and $_.ITApplicationowneremail -eq $item.ITApplicationowneremail -and $_.Businesscriticality -eq $item.Businesscriticality -and $_.Environment -eq $item.Environment}
      $item = Remove-PnPListItem -List $lst -Identity  $collectionid.id -Force
      Write-Log -Message "Removed $($collectionid.id) - $($collectionid.Application)" -path $log
      
    }
  }
elseif ($removal.CostCenterID.count -ge $countofchanges) 
  {
    Write-Log -message "Count of changes $($removal.CostCenterID.count) are more than $countofchanges - Please Check SyncCSV2SpoList" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Count of changes are more than $countofchanges - Please Check SyncCSV2SpoList" -Body "Count of changes are more than $countofchanges - Please Check SyncCSV2SpoList"
  }

#############################Now Recycle the logs############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - SyncCSV2SpoList" -Attachments $log
Disconnect-PnPOnline
#############################completed########################################################
