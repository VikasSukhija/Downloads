<#PSScriptInfo

    .VERSION 1.0

    .GUID 27a1d5f9-bd64-4086-8a49-3c730a9f6b56

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
    Created on:   	8/24/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AzureDisksReport.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This will generate Azure Disks report across the organization

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "CloudAzureDisks" -folder "logs" -Ext "log"
$Report = Write-Log -Name "CloudAzureDisks" -folder "Report" -Ext "csv"

$smtpserver = "smtpserver"
$from = "DoNotRespond@labtest.com"
$email1 = "VikasS@labtest.com"
$erroremail = "Report@labtest.com"

$logrecyclelimit = "60"
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
#######################################################################
try
{
  Write-Log -message "Start ......... Script" -path $log
  Connect-AzAccount -Credential $Credential
  Write-Log -message "Loaded All Modules" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Modules - CloudAzureDisks" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - CloudAzureDisks" -Body $($_.Exception.Message)
  break;
}

################################Query all SQL instances########################
try{
Write-Log -message "Query all Subscriptions in Azure" -path $log
# Get all subscriptions
$subIds = Get-AzSubscription | where{$_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory"} | Select-Object Id,Name
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Subscription - CloudAzureDisks" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "exception $exception has occured loading Subscription - CloudAzureDisks" -Body $($_.Exception.Message)
  break;
}

##########################Loop thru all subscripotions and get SQL Instances################
$collinventory = @()
foreach ($subId in $subIds) {
  $subscriptionId=$subscriptionName=$null
  $subscriptionId = $subid.Id
  $subscriptionName = $subid.Name
  Set-AzContext -SubscriptionId $subscriptionId
  Write-Log -message "Processing ........$subscriptionName" -path $log
  $disks=$null
  $disks = Get-AzDisk
  if($disks){
  foreach ($disk in $disks) {
    $mcoll = "" | Select SubscriptionName,SubscriptionId,DiskName,DiskID,DiskSizeGB,DiskSKUName,DiskLocation,ResourceGroupName
    $mcoll.SubscriptionName = $subscriptionName
    $mcoll.SubscriptionId = $subscriptionId
    $mcoll.DiskName = $disk.Name
    $mcoll.DiskID = $disk.Id
    $mcoll.DiskSizeGB = $disk.DiskSizeGB
    $mcoll.DiskSKUName = $disk.Sku.Name
    $mcoll.DiskLocation = $disk.Location
    $mcoll.ResourceGroupName = $disk.ResourceGroupName
    $collinventory += $mcoll

  }
}
}
##########################Error Handling################
if($error){
    Write-Log -message "exception $errot has occured loading Disks - CloudAzureDisks" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - CloudAzureDisks" -Body $Error[0].ToString()
}
##########################Export to CSV################
$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -cc $email2 -bcc $erroremail -Subject "Report - CloudAzureDisks" -Attachments $Report
Disconnect-AzAccount
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - CloudAzureDisks" -Attachments $log