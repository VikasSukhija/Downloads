<#PSScriptInfo

    .VERSION 1.0

    .GUID 121c06a0-3a45-4b7d-8186-108f849c5d64

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
    Created on:   	10/26/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	findduplicateobjects.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This will run on AD and find any duplicate objects that are created

#> 
param()
#################logs and variables#########################################
$log = Write-Log -Name "findduplicateobjects" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "Report-findduplicateobjects-Users" -folder "Report" -Ext "csv"
$Report2 = Write-Log -Name "Report-findduplicateobjects-Groups" -folder "Report" -Ext "csv"
	
$smtpserver = "smtpserver"
$erroremail = "Reports@labtest.com"
$email1 = "Alertmail1@labtest.com","Alertmail1@labtest.com"
$from = "DoNotReply@labtest.com"
$logrecyclelimit = "60"

$ObjFilter1 = "(&(objectClass=user)(objectCategory=person))"
$ObjFilter2 = "(&(objectClass=group)(objectCategory=group))"

#########################################################
  Write-Log -Message "Start ......... Script" -path $log
  try
  { 
    Write-Log -Message "Find Duplicate Users" -path $log
    $data = Get-ADUser -LDAPFilter $ObjFilter1 -Properties whenCreated | Select DistinguishedName, SamAccountName, Enabled,whenCreated
    $findsduplicateusers = $data.Where{$_.SamAccountName -like "*DUPLICATE*"}
    Write-Log -Message "Found Duplicate Users - $($findsduplicateusers.SamAccountName.count)" -path $log
    if($findsduplicateusers.SamAccountName.count -gt 0){
      $findsduplicateusers | Select DistinguishedName, SamAccountName, Enabled,whenCreated | Export-Csv $Report1 -NoTypeInformation
      Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - findduplicateobjects - Users" -Attachments $Report1
    }
    $data = $null
    Write-Log -Message "Find Duplicate Groups" -path $log
    $data = Get-ADGroup -LDAPFilter $ObjFilter2 -Properties whenCreated |Select DistinguishedName, SamAccountName,whenCreated
    $findsduplicategroups = $data.Where{$_.SamAccountName -like "*DUPLICATE*"}
    Write-Log -Message "Found Duplicate Groups - $($findsduplicategroups.SamAccountName.count)" -path $log
    if($findsduplicategroups.SamAccountName.count -gt 0){
      $findsduplicategroups | Select DistinguishedName, SamAccountName,whenCreated | Export-Csv $Report2 -NoTypeInformation
      Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Error - findduplicateobjects - Groups" -Attachments $Report2
    }

  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - findduplicateobjects" -Body $($_.Exception.Message)
  }

#########################Recycle logs###########################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Set-Recyclelogs -foldername "Report" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Finished..........processing" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - findduplicateobjects" -Body "Log - findduplicateobjects" -Attachments $log
#################################################################