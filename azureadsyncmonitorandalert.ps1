<#PSScriptInfo

    .VERSION 1.0

    .GUID 8df70530-6daf-41a8-8803-d225f84e1afa

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

      Author: Mayank Agarwal/Vikas Sukhija
      Reviewed/updated by: Vikas Sukhija
      Date: 11/15/2024
      Updated:   11/15/2024 - added loging alerting to be added gitlab acsi(vsadmin)
      Description: azureadsyncmonitorandalert
   ===========================================================================
#>

<# 

    .DESCRIPTION 
    azureadsyncmonitorandalert

#> 
param()
##########################Variables###############################
$log = Write-Log -Name "azureadsyncmonitorandalert" -folder "logs" -Ext "log"
$timeThreshold = (Get-Date).AddHours(-2).ToUniversalTime()

$logrecyclelimit = "60"

###################Admin params##########################
$smtpserver = "smtpservdr.labtest.com"
$erroremail = "erroremail@labtest.com"
$email1 = "reports@labtest.com"
$email2 = "Vikas@labtest.com"
$from = $readini["Admin"].From
######################Spo Cet Auth#########################
$TenantName = "techwizard.onmicrosoft.com"
$MgGClientID = "fkjkjnlknlknjhvcbkojl"
$ThumbPrint= "ttuyyuyyknkllkshfikkkkkkffs"
####################################################################
Write-Log -Message "Start ..............Script" -path $log 
try
  {
    Connect-MgGraph -ClientId $MgGClientID -CertificateThumbprint $ThumbPrint -TenantId $TenantName
    Write-Log -message "Loaded All Modules" -Path $log
    $syncEvents = Get-MgOrganization
    $lastsynctime = $syncEvents.OnPremisesLastSyncDateTime
    #####################get-datetime in UTC timezone###################
    Write-Log -message "Last Sync Time: $lastsynctime" -Path $log
    Write-log -message "Time Threshold: $timeThreshold" -Path $log
    if($lastsynctime -lt $timeThreshold){
        write-log -message "Last sync time is more than 2 hours ago" -path $log
        $subject = "High Alert! - Azure AD Sync Status"
        $body = "Please check Azure AD Sync status as the last sync ran more than 2 hours ago"
        Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -cc $email2 -bcc $erroremail -Subject $subject -Body $body
    }
    Disconnect-MgGraph
  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured loading graph - azureadsyncmonitorandalert" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - azureadsyncmonitorandalert" -Body $($_.Exception.Message)
    break;
  }
  ########################Recycle reports & logs##############
  Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -confirm:$false
  Write-Log -Message "Script Finished" -path $log
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - azureadsyncmonitorandalert" -Attachments $log