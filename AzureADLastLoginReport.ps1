<#PSScriptInfo

.VERSION 1.0

.GUID 1ba45abc-d909-42d5-8cae-3ae7b7b81c2e

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
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	5/1/2023  1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AzureADLastLoginReport.ps1
    refrence:   Microsoft script
    ===========================================================================
    .DESCRIPTION
    This script will report on AzureAd last login and can send the report on designated emaail address
    also you can filter the reports based on days, like whoever has not loggedin since 90days so 
    that in case you want to deactivate guest accounts or other accounts based on that. 

    User.Read.All and AuditLog.Read.All permissions are required for the APP
#>
[CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    $DaysSinceLastLogin,
    [Parameter(Mandatory = $true)]
    [ValidateSet('guest','member','All')]
    $UserType,
    $smtpserver="smtpserver",
    $from="DoNotRespond@labtest.com",
    $erroremail="Reports@labtest.com",
    $logrecyclelimit = '60'
  ) 
 
#################logs and variables##########################
$log = Write-Log -Name "AzureADLastLoginReport" -folder "logs" -Ext "log"
$ReportFull = Write-Log -Name "ReportFull-AzureADLastLoginReport" -folder "Report" -Ext "csv"
$ReportActual = Write-Log -Name "ReportActual-AzureADLastLoginReport" -folder "Report" -Ext "csv"
$URI = "https://graph.microsoft.com/beta/users?`$select=displayName,userPrincipalName, mail, id, CreatedDateTime, signInActivity, UserType, assignedLicenses&`$top=999"

#####################get access token ##############################
$AppId = ''
$TenantId = ''
$AppSecret = ''

$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
 $body = @{
     client_id     = $AppId
     scope         = "https://graph.microsoft.com/.default"
     client_secret = $AppSecret
     grant_type    = "client_credentials" }

$tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing
$Accesstoken = ($tokenRequest.Content | ConvertFrom-Json).access_token
#######################get report based on days#########################
Write-Log -Message "Start....................Script" -path $log
$headers = @{Authorization = "Bearer $Accesstoken"}
$SignInData = (Invoke-RestMethod -Uri $URI -Headers $Headers -Method Get -ContentType "application/json") 
switch($UserType){
"guest"{$SignInDatareport = $SignInData.value | where{$_.userType -eq 'Guest'}}
"member"{$SignInDatareport = $SignInData.value | where{$_.userType -eq 'member'}}
"All"{$SignInDatareport = $SignInData.value }
}
Write-Log -message "Fetched user sign-in data" -path $log
$pagecount = 1
##########generate report############
$Report = [System.Collections.Generic.List[Object]]::new() 
Foreach ($User in $SignInDatareport) {
    If ($Null -ne $User.SignInActivity.lastSignInDateTime){$LastSignInDateTime = [DateTime]$User.SignInActivity.LastSignInDateTime}
    else{$LastSignInDateTime = "" }
    if($Null -ne $User.SignInActivity.LastNonInteractiveSignInDateTime){$LastNonInteractiveSignInDateTime = [DateTime]$User.SignInActivity.LastNonInteractiveSignInDateTime}
    else{$LastNonInteractiveSignInDateTime = ""}    
    
    $ReportLine  = [PSCustomObject] @{          
      UPN                = $User.UserPrincipalName
      DisplayName        = $User.DisplayName
      Email              = $User.Mail
      Id                 = $User.Id
      Created            = [DateTime]$User.CreatedDateTime  
      LastSignInDateTime = $LastSignInDateTime
      LastNonInteractiveSignInDateTime = $LastNonInteractiveSignInDateTime
      UserType           = $User.UserType 
      IsLicensed  = if ($User.assignedLicenses.Count -ne 0) { $true } else { $false } }
      $Report.Add($ReportLine) 
 } # End ForEach

 # Go to next page to fetch more data
 $NextLink = $SignInData.'@Odata.NextLink'
    
 While ($NextLink -ne $Null) { # We do... so process them.
    $pagecount = $pagecount + 1
    Write-log -message "Processing Page - $pagecount" -path $log
    $SignInData =  Invoke-RestMethod -Uri $NextLink -Headers $Headers -Method Get -ContentType "application/json"

    switch($UserType){
      "guest"{$SignInDatareport = $SignInData.value | where{$_.userType -eq 'Guest'}}
      "member"{$SignInDatareport = $SignInData.value | where{$_.userType -eq 'member'}}
      "All"{$SignInDatareport = $SignInData.value}
      }
Foreach ($User in $SignInDatareport) {  
    If ($Null -ne $User.SignInActivity.lastSignInDateTime){$LastSignInDateTime = [DateTime]$User.SignInActivity.LastSignInDateTime}
    else{$LastSignInDateTime = "" }
    if($Null -ne $User.SignInActivity.LastNonInteractiveSignInDateTime){$LastNonInteractiveSignInDateTime = [DateTime]$User.SignInActivity.LastNonInteractiveSignInDateTime}
    else{$LastNonInteractiveSignInDateTime = ""}   
         
    $ReportLine  = [PSCustomObject] @{          
      UPN                = $User.UserPrincipalName
      DisplayName        = $User.DisplayName
      Email              = $User.Mail
      Id                 = $User.Id
      Created            = [DateTime]$User.CreatedDateTime  
      LastSignInDateTime = $LastSignInDateTime
      LastNonInteractiveSignInDateTime = $LastNonInteractiveSignInDateTime
      UserType           = $User.UserType
      IsLicensed  = if ($User.assignedLicenses.Count -ne 0) { $true } else { $false } } 
      $Report.Add($ReportLine) }
    
    # Check for more data
    $NextLink = $SignInData.'@Odata.NextLink'
 } # End While


Write-log -message "All pages processed - export report - $($Report.count)" -path $log
###############################process last login data##########################################
$ReportCreatedpast90days = $Report | where{$(get-date $_.Created)  -lt (get-date).AddDays(-$DaysSinceLastLogin)}

[System.Collections.ArrayList]$collection = @() 
foreach($i in $ReportCreatedpast90days){
  $mcoll = "" | Select-Object UPN,DisplayName,Email ,Id ,Created ,LastSignInDateTime,LastNonInteractiveSignInDateTime, UserType ,IsLicensed, Status
  $mcoll.UPN = $i.UPN
  $mcoll.DisplayName = $i.DisplayName
  $mcoll.Email = $i.Email
  $mcoll.Id = $i.Id
  $mcoll.Created = $i.Created
  $mcoll.UserType = $i.UserType
  $mcoll.IsLicensed = $i.IsLicensed
  if($i.LastSignInDateTime -eq "" -and $i.LastNonInteractiveSignInDateTime -eq ""){
  $mcoll.LastSignInDateTime = $i.LastSignInDateTime
  $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
  $mcoll.status = "NullData"

  }
  elseif($i.LastSignInDateTime -eq "" -and $i.LastNonInteractiveSignInDateTime -ne ""){
  if($(get-date $i.LastNonInteractiveSignInDateTime) -lt (get-date).AddDays(-$DaysSinceLastLogin)){
  $mcoll.LastSignInDateTime = $i.LastSignInDateTime
  $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
  $mcoll.status = "Deactivate"
  }else{
    $mcoll.LastSignInDateTime = $i.LastSignInDateTime
    $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
    $mcoll.status = "NoAction"
  }
  }
  elseif($i.LastSignInDateTime -ne "" -and $i.LastNonInteractiveSignInDateTime -eq ""){
    if($(get-date $i.LastSignInDateTime) -lt (get-date).AddDays(-$DaysSinceLastLogin)){
  $mcoll.LastSignInDateTime = $i.LastSignInDateTime
  $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
  $mcoll.status = "Deactivate"
  }else{
    $mcoll.LastSignInDateTime = $i.LastSignInDateTime
    $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
    $mcoll.status = "NoAction"
  }

  }
  else{
  if($(get-date $i.LastSignInDateTime) -gt $(get-date $i.LastNonInteractiveSignInDateTime)){
  if($(get-date $i.LastSignInDateTime) -lt (get-date).AddDays(-$DaysSinceLastLogin)){
  $mcoll.LastSignInDateTime = $i.LastSignInDateTime
  $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
  $mcoll.status = "Deactivate"
  }else{
    $mcoll.LastSignInDateTime = $i.LastSignInDateTime
    $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
    $mcoll.status = "NoAction"
  }

  }
  else{
    if($(get-date $i.LastNonInteractiveSignInDateTime) -lt (get-date).AddDays(-$DaysSinceLastLogin)){
  $mcoll.LastSignInDateTime = $i.LastSignInDateTime
  $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
  $mcoll.status = "Deactivate"
  }else{
    $mcoll.LastSignInDateTime = $i.LastSignInDateTime
    $mcoll.LastNonInteractiveSignInDateTime = $i.LastNonInteractiveSignInDateTime
    $mcoll.status = "NoAction"
  }

  }

  }

  $collection.Add($mcoll)
}
###########################Exatract reports#################################
$collection | export-csv $ReportFull -NoTypeInformation
$deletecollection = $collection | Where{$_.Status -eq 'Deactivate' -or $_.Status -eq 'NullData'} 
$deletecollection | export-csv $ReportActual -NoTypeInformation
if($error){
  Write-Log -message "Error - $error" -path $log
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Guest Deletion will not occur AzureADLastLoginReport" -Body $error[0].ToString()
  exit
}
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -confirm:$false
Set-Recyclelogs -foldername "Report" -limit $logrecyclelimit -confirm:$false
Write-Log -Message "Script Finished" -path $log
#############################completed####################################