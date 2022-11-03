<#PSScriptInfo

.VERSION 1.0

.GUID 7944e874-eb33-496b-89c6-790bb28675df

.AUTHOR Vikas Sukhija

.COMPANYNAME Techwizard.cloud

.COPYRIGHT Techwizard.cloud

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 flowmonitorandalert 

#> 

<#	
    .NOTES
    ==========================================================================
    Created with: 	ISE
    Created on:   	9/27/2022 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	flowmonitorandalert.ps1

    ==========================================================================
    .DESCRIPTION
    This script will monitor flows for particular users in particular Environments
#>
param (
  [string]$CreatedbyGUID,#Enter Guid of the user - ObjectID
  [string]$FlowNamematch, #Enter Flow Name if not using CreatedbyGUID
  [string]$EnvironmentName = $(Read-Host "Enter Enviornment GUID"),
  [string]$smtpserver = $(Read-Host -Prompt "Enter SMTP Server"),
  [string]$from = $(Read-Host -Prompt "Enter From Address"),
  [string]$erroremail = $(Read-Host -Prompt "Enter Address for Report and Errors")
)
New-FolderCreation -foldername temp
#####################Log and Variables#################################
$log = Write-Log -Name "flowmonitorandalert" -folder "logs" -Ext "log"
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
Write-Log -Message "Start ....................Script" -path $log
try{
  Add-PowerAppsAccount -Username $Credential.UserName -Password $Credential.Password
}
catch{
  $exception = $($_.Exception.Message)
  Write-log -message "Exception $exception has occured" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - flowmonitorandalert" -Body $exception
  exit
}
#########fetch flows based on above criteria daily at 11 PM#####################

try{
if((($CreatedbyGUID) -and ($(get-date).TimeOfDay.Hours -eq 23)) -or (($CreatedbyGUID) -and $(Test-Path -path $($(get-location).Path + "\temp\$CreatedbyGUID-$EnvironmentName.xml")) -eq $false)){
  Write-log -message "Extracting - $CreatedbyGUID $EnvironmentName" -path $log
  Get-AdminFlow -CreatedBy $CreatedbyGUID -EnvironmentName $EnvironmentName | select DisplayName, FlowName, CreatedBy, EnvironmentName, Enabled,CreatedTime, LastModifiedTime | Export-Clixml ".\temp\$CreatedbyGUID-$EnvironmentName.xml"
  Write-log -message "Extracted - $CreatedbyGUID $EnvironmentName" -path $log
}elseif((($FlowNamematch) -and ($(get-date).TimeOfDay.Hours -eq 23)) -or (($FlowNamematch) -and $(Test-Path -path $($(get-location).Path + "\temp\$FlowNamematch-$EnvironmentName.xml")) -eq $false))
{
 Write-log -message "Extracting - $FlowNamematch $EnvironmentName" -path $log
 Get-AdminFlow *$FlowNamematch* -EnvironmentName $EnvironmentName | select DisplayName, FlowName, CreatedBy, EnvironmentName, Enabled,CreatedTime, LastModifiedTime | Export-Clixml ".\temp\$FlowNamematch-$EnvironmentName.xml"
 Write-log -message "Extracted - $FlowNamematch $EnvironmentName" -path $log
}else{
  Write-log -message "CreatedBy and Flow Name condtions not met for generation" -path $log
}
}
catch{
  $exception = $($_.Exception.Message)
  Write-log -message "Exception $exception has occured" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - flowmonitorandalert" -Body $exception
  exit
}

##########################Monitor the Enabled Flows######################
if($CreatedbyGUID){
  $monitorflows = Import-Clixml ".\temp\$CreatedbyGUID-$EnvironmentName.xml" | where{$_.Enabled -eq $true}
  }
  elseif($FlowNamematch){
  $monitorflows = Import-Clixml ".\temp\$FlowNamematch-$EnvironmentName.xml" | where{$_.Enabled -eq $true}
}
else{
  Write-log -message "CreatedBy and Flow Name both Values are null " -path $log -Severity Error
  timeout 20
  Exit
}
Write-log -message "Monitor Flow Count - $($monitorflows.Count)" -path $log
foreach($flow in $monitorflows){
    Write-log -message "Fetch flow run for $($flow.DisplayName)" -path $log
    $getdate = (Get-Date).AddHours(-2)
    $getflowrun = Get-FlowRun -FlowName $flow.FlowName -EnvironmentName $EnvironmentName
    $previous2hrsflowruns = $getflowrun | where{(get-date $_.StartTime) -gt $getdate}
    foreach($hflow in $previous2hrsflowruns){
    if($hflow.Status -eq "Failed"){
    Write-log -message "failed Flow - $($flow.DisplayName) - $($flow.FlowName)" -path $log
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - flow failed - $($flow.DisplayName)" -Body "Error - flow failed - $($flow.DisplayName)"
    }
    }
  }

#############################recycel logs###########################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false

Write-Log -Message "Script .......Finished" -path $log
#Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Transcript Log - flowmonitorandalert" -Attachments $log
####################################################################
