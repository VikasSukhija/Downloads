<#PSScriptInfo

    .VERSION 1.0

    .GUID 4b2fa65a-c028-47cc-bf2b-e87ac67c663f

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
    Created on:   	10/31/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AzureStorageAccountsUsage.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This solution will replace cloudhealth inventory report for Azure Disk report

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "AzureStorageAccountsUsage" -folder "logs" -Ext "log"
$Failedlog = Write-Log -Name "Error-AzureStorageAccountsUsage" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AzureStorageAccountsUsage" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"
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
try {
  Write-Log -message "Start ......... Script" -path $log
  Connect-AzAccount -Credential $Credential
  Write-Log -message "Loaded All Modules" -path $log
}
catch {
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Modules - AzureStorageAccountsUsage" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AzureStorageAccountsUsage" -Body $($_.Exception.Message)
  break;
}
################################Query all SQL instances########################
try {
  Write-Log -message "Query all Subscriptions in Azure" -path $log
  # Get all subscriptions
  $subIds = Get-AzSubscription | where { $_.State -eq "Enabled" -and $_.Name -ne "Access to Azure Active Directory" } | Select-Object Id, Name
  Write-Log -message "Found ........$($subIds.count) Subscriptions" -path $log
}
catch {
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Subscription - AzureStorageAccountsUsage" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error -   Write-Log -message "exception $exception has occured loading Subscription - AzureStorageAccountsUsage" -path $log -Severity Error  " -Body $($_.Exception.Message)
  break;
}

##########################Loop thru all subscripotions and get SQL Instances################
$collinventory = @()
foreach ($subId in $subIds) {
  $subscriptionId = $subscriptionName = $null
  $subscriptionId = $subid.Id
  $subscriptionName = $subid.Name
  Set-AzContext -SubscriptionId $subscriptionId
  Write-Log -message "Processing ........$subscriptionName" -path $log
  $storageAccounts = $null
  $storageAccounts = Get-AzStorageAccount
  if ($storageAccounts) {
    Write-Log -message "Found ........$($storageAccounts.count) Storage Accounts" -path $log
    foreach ($storageAccount in $storageAccounts) {
      $resourceId = $metric = $null
      Write-Log -message "Processing................$($storageAccount.StorageAccountName)" -path $log
          $mcoll = "" | Select SubscriptionName, SubscriptionId, StorageAccountName, StorageAccountID, StorageAccountType, StorageAccountLocation, ResourceGroupName, SizeInGB
          $mcoll.SubscriptionName = $subscriptionName
          $mcoll.SubscriptionId = $subscriptionId
          $mcoll.StorageAccountName = $storageAccount.StorageAccountName
          $mcoll.StorageAccountID = $storageAccount.Id
          $mcoll.StorageAccountType = $storageAccount.Kind
          $mcoll.StorageAccountLocation = $storageAccount.Location
          $mcoll.ResourceGroupName = $storageAccount.ResourceGroupName
          $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$($storageAccount.ResourceGroupName)/providers/Microsoft.Storage/storageAccounts/$($storageAccount.StorageAccountName)"
          $metric = (Get-AzMetric -ResourceId  $resourceId -MetricName "UsedCapacity" -StartTime "02:00:00" -EndTime "04:00:00")
          $mcoll.SizeInGB = [Math]::Round($metric.data[0].Average / (1GB), 2)
          $collinventory += $mcoll
          if ($error){
            Write-Log -message "Error $($error) has occured - $subscriptionName - $($storageAccount.StorageAccountName) - $($container.Name) - resource group $($storageAccount.ResourceGroupName)" -path $log -Severity Error
            Write-Log -message "Error has occured - $subscriptionName - $($storageAccount.StorageAccountName) - $($container.Name) - resource group $($storageAccount.ResourceGroupName)" -path $Failedlog -Severity Error
            Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - $subscriptionName - $($storageAccount.StorageAccountName) - $($container.Name) - AzureStorageAccountsUsage" -Body $Error[0].ToString()
            $error.clear()
          }
    }
  }
}


##########################Error Handling################
if ($error) {
  Write-Log -message "exception $($error) has occured loading Disks - AzureStorageAccountsUsage" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AzureStorageAccountsUsage" -Body $Error[0].ToString()
}
##########################Export to CSV################
$collinventory | Export-Csv $report -NoTypeInformation
$sumofstorage = $collinventory | ForEach-Object { $_.SizeInGB } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Report: $($collinventory.count) Azure Storage Accounts - Total $sumofstorage GB" -Attachments $Report
Disconnect-AzAccount
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AzureStorageAccountsUsage" -Attachments $log