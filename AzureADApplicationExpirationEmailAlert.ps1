<#PSScriptInfo
    .VERSION 1.0
    .GUID 7c6db482-5850-4f98-a4bd-80275be3c2f3
    .AUTHOR Vikas Sukhija
    .COMPANYNAME techwizard.cloud
    .COPYRIGHT techwizard.cloud
    .TAGS
    .LICENSEURI 
    .PROJECTURI 
    .ICONURI
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES
    .PRIVATEDATA

    Created with: 	ISE
    Created on:   	10/24/2021 10:40 AM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AzureADApplicationExpirationEmailAlert.ps1
#>

<# 
    .DESCRIPTION 
     Alert Notification for AzureADApplication Certs and Secrets
#> 
[CmdletBinding()]
  param
  ( 
    [Array]$daystoexpiryleft = @(60,15,1),
    [Parameter(Mandatory = $true)]
    [ValidateSet('Alert','AlertOwner','ReportOnly')]
    $SendAlert,
    [Parameter(Mandatory = $true)]
    $smtpserver,
    [Parameter(Mandatory = $true)]
    $from,
    [Parameter(Mandatory = $true)]
    $erroremail,
    $logrecyclelimit = '60' 
  ) 
################################Load modules#################
import-module vsadmin
import-module AzureAD
####################Variables/Logs###########################
$log = Write-Log -Name "AzureADApplicationExpirationAlert" -folder "logs" -Ext "log"
$report1 = Write-Log -Name "AzureADApplication-FullReport" -folder "Report" -Ext "csv"

#############################################################
 Write-Log -Message "Start ................Script" -path $log
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
try
{
  Connect-AzureAD -Credential $Credential
  Write-Log -Message "Fetching................Applications" -path $log
  $applications = Get-AzureADApplication -All $true
  Write-Log -Message "Fetched Applications - $($applications.count)" -path $log
  Write-Log -Message "Fetching................ServicePrincipals" -path $log
  $servicePrincipals = Get-AzureADServicePrincipal -All $true
  Write-Log -Message "Fetched ServicePrincipals - $($servicePrincipals.count)" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message "exception $exception has occured"  -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Connecting Azure - AzureADApplicationExpirationAlert" -Body $exception 
  Exit
}
#############################Generate the Report now################
$collection = @()
$applications  |  ForEach-Object{
  $owner = (Get-AzureADApplicationOwner -ObjectId $_.ObjectId).UserPrincipalName -join ";"
  $cert = $_.KeyCredentials
  $PasswordCredentials = $_.PasswordCredentials
  $DisplayName = $_.DisplayName
  $ObjectId = $_.ObjectId
  $Appid = $_.AppId
  $sPrincipal= $servicePrincipals | where{$_.appid -eq $Appid}
  $ObjectType = $_.ObjectType
  Write-log -message "Porcessing............$DisplayName" -path $log
  if($cert){
    $cert | ForEach-Object{
      $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $keyId = $_.KeyId
            $certExpirationDate = $_.EndDate
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = $keyId 
            $coll.certExpirationDate = $(get-date $certExpirationDate)
            $coll.SecretKeyID = "NA" 
            $coll.SecretExpirationDate = "NA"
            $coll.SAMLKeyID = "NA" 
            $coll.SAMLCertExpirationDate = "NA"
            $coll.SAMLType = "NA" 
            $coll.SAMLUsage = "NA"
            $collection+=$coll
          }
  }
  elseif($PasswordCredentials){
    $PasswordCredentials | ForEach-Object{
      $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $keyId = $_.KeyId
            $certExpirationDate = $_.EndDate
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = "NA"
            $coll.certExpirationDate = "NA"
            $coll.SecretKeyID = $keyId 
            $coll.SecretExpirationDate = $(get-date $certExpirationDate)
            $coll.SAMLKeyID = "NA" 
            $coll.SAMLCertExpirationDate = "NA"
            $coll.SAMLType = "NA" 
            $coll.SAMLUsage = "NA"
            $collection+=$coll
          }
  }
  elseif($sprincipal.KeyCredentials){
    $sprincipal.KeyCredentials | ForEach-Object{
      $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $keyId = $_.KeyId
            $certExpirationDate = $_.EndDate
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = "NA"
            $coll.certExpirationDate = "NA"
            $coll.SecretKeyID = "NA"
            $coll.SecretExpirationDate = "NA"
            $coll.SAMLKeyID = $keyId 
            $coll.SAMLCertExpirationDate = $(get-date $certExpirationDate)
            $coll.SAMLType = $_.Type
            $coll.SAMLUsage = $_.Usage
            $collection+=$coll
          }
  }
  else{
    $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = "NA"
            $coll.certExpirationDate = "NA"
            $coll.SecretKeyID = "NA" 
            $coll.SecretExpirationDate = "NA"
            $coll.SAMLKeyID = "NA" 
            $coll.SAMLCertExpirationDate = "NA"
            $coll.SAMLType = "NA" 
            $coll.SAMLUsage = "NA"
            $collection+=$coll
  }
}
if($error){Write-Log -Message "error $error has occured"  -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AzureADApplicationExpirationAlert" -Body $error[0].tostring() 
  exit
}
$collection | export-csv $report1 -NoTypeInformation
Disconnect-AzureAD

#########################Alert Function based on Gathered data####################
function Write-ExpiryAlert{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    $collection,
    [Parameter(Mandatory = $true)]
    $daystoexpiryleft,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Alert','AlertOwner','ReportOnly')]
    $SendAlert
  ) 
  try{
    if($SendAlert -eq "Alert"){
      $report = Write-Log -Name $("AzureADApplication-ExpiryReport-Alert" + "$daystoexpiryleft" + "_") -folder "Report" -Ext "csv"
      $collexpiry = $collection | where{($_.certExpirationDate -ne "NA" -and $(get-date $_.certExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d)) -or ($_.SecretExpirationDate -ne "NA" -and $(get-date $_.SecretExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d)) -or ($_.SAMLCertExpirationDate -ne "NA" -and $(get-date $_.SAMLCertExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d))} 
      if($collexpiry){$collexpiry  | export-csv $report -NoTypeInformation
        $collexpiry | foreach-object{
          $item = @"
              DisplayName = $($_.DisplayName)
              ObjectId = $($_.ObjectId)
              AppId = $($_.AppId)
              ObjectType = $($_.ObjectType)
              Owner = $($_.Owner)
              CertKeyID = $($_.CertKeyID)
              certExpirationDate = $($_.certExpirationDate)
              SecretKeyID = $($_.SecretKeyID)
              SecretExpirationDate = $($_.SecretExpirationDate)
              SAMLKeyID = $($_.SAMLKeyID)
              SAMLCertExpirationDate = $($_.SAMLCertExpirationDate)
              SAMLType = $($_.SAMLType)
              SAMLUsage = $($_.SAMLUsage)
              daystoexpiryleft = $daystoexpiryleft

"@
          Write-log -message "Sending alert for - $($_.DisplayName)" -path $log
          Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Alert - AzureAD Application Cert Secret Expiration" -Body $item 
        }
      }
    }
    if($SendAlert -eq "AlertOwner"){
      $report = Write-Log -Name $("AzureADApplication-ExpiryReport-Owner" + "$daystoexpiryleft" + "_") -folder "Report" -Ext "csv"
        $collexpiry = $collection | where{($_.certExpirationDate -ne "NA" -and $(get-date $_.certExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d)) -or ($_.SecretExpirationDate -ne "NA" -and $(get-date $_.SecretExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d)) -or ($_.SAMLCertExpirationDate -ne "NA" -and $(get-date $_.SAMLCertExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d))} | where {$_.owner} 
        if($collexpiry){
          $collexpiry | export-csv $report -NoTypeInformation
          $collexpiry | foreach-object{

            $item = @"
              DisplayName = $($_.DisplayName)
              ObjectId = $($_.ObjectId)
              AppId = $($_.AppId)
              ObjectType = $($_.ObjectType)
              Owner = $($_.Owner)
              CertKeyID = $($_.CertKeyID)
              certExpirationDate = $($_.certExpirationDate)
              SecretKeyID = $($_.SecretKeyID)
              SecretExpirationDate = $($_.SecretExpirationDate)
              SAMLKeyID = $($_.SAMLKeyID)
              SAMLCertExpirationDate = $($_.SAMLCertExpirationDate)
              SAMLType = $($_.SAMLType)
              SAMLUsage = $($_.SAMLUsage)
              daystoexpiryleft = $daystoexpiryleft
"@
           
            Write-log -message "Sending alert for - $($_.DisplayName) to $($_.Owner)" -path $log
            $owneremail = $($_.Owner) -split ";"
            Send-MailMessage -SmtpServer $smtpserver -From $from -To $owneremail -cc $erroremail -Subject "Alert - AzureAD Application Cert Secret Expiration" -Body $item
          }
        }
        }
      if($SendAlert -eq "ReportOnly"){
      $report = Write-Log -Name $("AzureADApplication-ExpiryReport-ReportOnly" + "$daystoexpiryleft" + "_") -folder "Report" -Ext "csv"
      $collexpiry = $collection | where{($_.certExpirationDate -ne "NA" -and $(get-date $_.certExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d)) -or ($_.SecretExpirationDate -ne "NA" -and $(get-date $_.SecretExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d)) -or ($_.SAMLCertExpirationDate -ne "NA" -and $(get-date $_.SAMLCertExpirationDate -Format d) -eq $(get-date (get-date).AddDays($daystoexpiryleft) -format d))} 
      if($collexpiry){$collexpiry  | export-csv $report -NoTypeInformation
          Write-log -message "Generated Report for Expirying CERTS and SECRETS - $daystoexpiryleft" -path $log
        }
      }

  }catch{
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured"  -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Connecting Azure - AzureADApplicationExpirationAlert" -Body $exception 
  }
}#Write-ExpiryAlert

###################Execute the fundtion#####################
$daystoexpiryleft | ForEach-Object{
  Write-Log -Message "Action - Days to Expiry left - $_ - $SendAlert"  -path $log
  Write-ExpiryAlert -collection $collection -daystoexpiryleft $_ -SendAlert $SendAlert
}
########################Recycle reports & logs##############
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Set-Recyclelogs -foldername "Report" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AzureADApplicationExpirationAlert" -Attachments $log
##########################################################################