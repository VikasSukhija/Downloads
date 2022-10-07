<#PSScriptInfo

.VERSION 1.0

.GUID f0d629e8-15ff-4652-a613-407a4e1c54a0

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard.cloud

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI TechWizard.cloud

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES 


.PRIVATEDATA

#>
<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	9/26/2022 1:46 PM
    Created by:   	Vikas Sukhija/Steve Johnson
    Organization: 	
    Filename:     	AzureMobileStaleDeviceCleanup.ps1
    ===========================================================================
    .DESCRIPTION
    Azure AD Stale Mobile Device Cleanup
#>
param (
  $LastActivityDisableDays = 90, # For disable
  $LastActivityDeleteDays = 120, # For deletetion
  $MobileOS = @(
     'iOS'
     'iPhone'
     'iPad'
     'iPad3,5'
     'iPod'
     'Android'
     'AndroidForWork'
    ),#Defines the mobile OS Types
  [Parameter(Mandatory = $false)]
  [ValidateSet('Report','Disable','Remove','DisableAndRemove')]
  [string]$Operation = 'Report',
  [string]$smtpserver = 'smtpserver.labtest.com',
  [string]$from = 'DoNotRespond@labtest.com',
  [string]$erroremail = 'Reports@labtest.com',
  $CountofChanges = 1000 #number of devices dletion or disable Threshhold
)
####################Load variables and log#######################
$log = Write-Log -Name "AzureMobileStaleDeviceCleanup-Log" -folder "logs" -Ext "log"
$report1 = Write-Log -Name "AzureDisableDevices" -folder "Report" -Ext "csv"
$report2 = Write-Log -Name "AzureDeleteDevices" -folder "Report" -Ext "csv"
$logrecyclelimit = 60

##################get-credentials##########################
Write-Log -message "Start ......... Script" -path $log
Write-Log -message "Get Crendetials for Admin ID" -path $log
if(Test-Path -Path ".\Password.xml")
{
  Write-Log -message "Password file Exists" -path $log
}
else
{
  Write-Log -message "Generate password" -path $log
  $Credential = Get-Credential 
  $Credential | Export-Clixml -Path ".\Password.xml"
}
#############################################################
$Credential = $null
$Credential = Import-Clixml -Path ".\Password.xml"
########################Start Script##############################

#Calculate the target date of now, less the number of days of last activity
$DisableThreshold = (Get-Date).AddDays(-$LastActivityDisableDays)
$DeleteThreshold = (Get-Date).AddDays(-$LastActivityDeleteDays)
#################Start main#######################################
Write-Log -message "Start ......... Script" -path $log
try{
    Connect-AzureAD -Credential $Credential
    Write-Log -message "Connected to AzureAD" -path $log
}
catch{
    $exception = $_.Exception.Message
    Write-Log -message "exception $exception has occured loading AzureAD" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AzureMobileStaleDeviceCleanup" -Body $exception
    break;
}

#========= DATA COLLECTION =========
try{
Write-Log -message "Collect all azure mobile devices" -path $log
$allAzureDevices = Get-AzureADDevice -All:$true | Where{$MobileOS -contains $_.DeviceOSType }
Write-Log -message "Azure mobile devices - $($allAzureDevices.Count)" -path $log
#Captures stale device records into collection that will be disabled
$DisableDevices = $allAzureDevices | Where-Object {($_.ApproximateLastLogonTimeStamp -le $DisableThreshold -and $_.ApproximateLastLogonTimeStamp -gt $DeleteThreshold)}
Write-Log -message "Azure mobile Disable devices - $($DisableDevices.Count)" -path $log
$DisableDevices | Select -Property AccountEnabled, DeviceId, DeviceOSType, DeviceOSVersion, DisplayName, DeviceTrustType, ApproximateLastLogonTimestamp | Export-Csv $report1 -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Report - AzureMobileStaleDeviceCleanup - Disable $LastActivityDisableDays" -Attachments $report1

#Captures stale device records into collection that will be deleted
$DeleteDevices = $allAzureDevices  | Where-Object {($_.ApproximateLastLogonTimeStamp -le $DeleteThreshold) -and ($MobileOS -contains $_.DeviceOSType )}
Write-Log -message "Azure mobile Delete devices - $($DeleteDevices.Count)" -path $log
$DeleteDevices | Select -Property AccountEnabled, DeviceId, DeviceOSType, DeviceOSVersion, DisplayName, DeviceTrustType, ApproximateLastLogonTimestamp | Export-Csv $report2 -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Report - AzureMobileStaleDeviceCleanup - Remove $LastActivityDeleteDays" -Attachments $report2
}
catch{
    $exception = $_.Exception.Message
    Write-Log -message "exception $exception has occured" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AzureMobileStaleDeviceCleanup" -Body $exception
    exit
}
#========= DEVICE Disable =========#
if(($Operation -eq 'Disable') -or ($Operation -eq 'DisableAndRemove')){
if(($DisableDevices.count -gt 0) -and ($DisableDevices.count -lt $countofchanges)){
Foreach($Disabled in $DisableDevices){
        $error.clear()
        Write-Log -message "Disabling device: $($Disabled.ObjectID) $($Disabled.DisplayName)" -path $log
        #Set-AzureADDevice -Objectid $Device.ObjectID -AccountEnabled $false
        if($error){
        Write-Log -message "Error - Disabling device: $($Disabled.ObjectID) $($Disabled.DisplayName)" -path $log
        } 
     }
}
 elseif($DisableDevices.count -ge $countofchanges){
 Write-log -message "Count of changes are more than $countofchanges - AzureMobileStaleDeviceCleanup" -path $log
 Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Count of Disable changes are more than $countofchanges - Please Check AzureMobileStaleDeviceCleanup" -Body "Count of Disable changes are more than $countofchanges - Please Check AzureMobileStaleDeviceCleanup"
}
}
#========= DEVICE Delete =========#
if(($Operation -eq 'Remove') -or ($Operation -eq 'DisableAndRemove')){
if(($DeleteDevices.count -gt 0) -and ($DeleteDevices.count -lt $countofchanges)){
Foreach($Deleted in $DeleteDevices){
        $error.clear()
        Write-Log -message "Deleting device: $($Deleted.ObjectID) $($Deleted.DisplayName)" -path $log
        #Remove-AzureADDevice -ObjectId $Deleted.ObjectID
        if($error){
        Write-Log -message "Error - Deleting device: $($Deleted.ObjectID) $($Deleted.DisplayName)" -path $log
        } 
     }
}
 elseif($DeleteDevices.count -ge $countofchanges){
 Write-log -message "Count of changes are more than $countofchanges - AzureMobileStaleDeviceCleanup" -path $log
 Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Count of Delete changes are more than $countofchanges - Please Check AzureMobileStaleDeviceCleanup" -Body "Count of Delete changes are more than $countofchanges - Please Check AzureMobileStaleDeviceCleanup"
}
}
Disconnect-AzureAD
########################Recycle reports & logs#############################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Set-Recyclelogs -foldername "report" -limit $logrecyclelimit -Confirm:$false
Write-Log -message "Script............Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AzureMobileStaleDeviceCleanup" -Body "Log - AzureMobileStaleDeviceCleanup" -Attachments $log
########################Script Finished####################################