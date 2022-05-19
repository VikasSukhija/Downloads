###############################################################
#			Author: Vikas Sukhija (http://techwizard.cloud)
#			Date: 8/4/2016
#			updated: 8/11/2016 (created heders/CSV logic)
#			Updated: 8/15/2016 (fixed service status when multiple licenses are there)
#			Updated: 10/7/2016 (updated for licensed users only)
#			Updated: 10/9/2016 (updated with html body to include total counts)
#			Updated: 12/21/2016 (updated New SKU PSTN)
#     Updated: 3/9/2018 (Updated with one drive link)
#     Updated: 7/1/2020 (Updated NEW SKUs)
#     Updated: 8/3/2020 (update Usage location)
#     Updated: 8/3/2020 (Use vsadmin module functions)
#     Updated: 8/3/2021 (update RPA license)
#     Updated: 4/3/2022 (update with graph module)
#			Description: Office 365 users Report
###############################################################
$output = Write-Log -Name "office365report" -folder "Report" -Ext "csv"
$log = Write-Log -Name "office365report-log" -folder "logs" -Ext "log"

$output1 = "E:\o365report\LicenseReport"

$email1 = "O365Report@techwizard.cloud"
$erroremail = "Reports@techwizard.cloud"

$from = "LicenseReport@techwizard.cloud"
$smtpserver = "smtp.techwizard.cloud"

$MgGClientID = "791907109m1u090m90970m975xmimhkjh"
$ThumbPrint = "6767835498189119001580197099009"
$TenantName = "techwizard.onmicrosoft.com"
############################################################
###############################################################
Write-Log -message "Start..................Script" -path $log

try
{
  Connect-MgGraph -ClientId $MgGClientID -CertificateThumbprint $ThumbPrint -TenantId $TenantName
  Select-MgProfile -Name "beta"
  Write-Log -Message "Load MGgraph"  -path $log
}
catch
{
  $exception = $($_.Exception.Message)
  Write-Log -Message "$exception" -path $log -Severity Error
  Write-Log -Message "Exception has occured in connecting Micrososft graph"  -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error has occured Loading MSGraph - LicenseReport"
  Exit;
}

################################################################################
Write-Log -message "Start fetching Account SKU" -path $log
$lict = Get-MgSubscribedSku | Select @{n="AccountSkuId";e={$_.SkuPartNumber}},@{n="ActiveUnits";e={$_.PrepaidUnits.Enabled}},@{n="WarningUnits";e={$_.PrepaidUnits.Warning}},ConsumedUnits,CapabilityStatus,ServicePlans,SkuId,SkuPartNumber
$embody = $lict | Select-Object AccountSkuId, ActiveUnits, WarningUnits, ConsumedUnits
$embody1 = @()

$embody | ForEach-Object{
  $license = $_.AccountSkuId
	
  ###########################
  $licensevalue = @()
  switch -Wildcard ($license)
  {
    "*DESKLESSPACK*" { $licensevalue += "Office 365 (Plan K1)" }
    "*DESKLESSWOFFPACK*" { $licensevalue += "Office 365 (Plan K2)" }
    "*LITEPACK*" { $licensevalue += "Office 365 (Plan P1)" }
    "*EXCHANGESTANDARD*" { $licensevalue += "Office 365 Exchange Online Only" }
    "*STANDARDPACK*" { $licensevalue += "Office 365 (Plan E1)" }
    "*ENTERPRISEPACK*" { $licensevalue += "Office 365 (Plan E3)" }
    "*ENTERPRISEPACKLRG*" { $licensevalue += "Office 365 (Plan E3)" }
    "*ENTERPRISEWITHSCAL*" { $licensevalue += "Office 365 (Plan E4)" }
    "*STANDARDPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A1) for Students" }
    "*ENTERPRISEPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A3) for Students" }
    "*ENTERPRISEWITHSCAL_STUDENT*" { $licensevalue += "Office 365 (Plan A4) for Students" }
    "*STANDARDPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A1) for Faculty" }
    "*STANDARDWOFFPACKPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A2) for Faculty" }
    "*ENTERPRISEPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A1) for Students" }
    "*STANDARDPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A1) for Students" }
    "*ENTERPRISEPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A3) for Faculty" }
    "*ENTERPRISEWITHSCAL_FACULTY*"{ $licensevalue += "Office 365 (Plan A4) for Faculty" }
    "*ENTERPRISEPACK_B_PILOT*" { $licensevalue += "Office 365 (Enterprise Preview)" }
    "*STANDARD_B_PILOT*" { $licensevalue += "Office 365 (Small Business Preview)" }
    "*VISIOCLIENT*"{ $licensevalue += "Office 365 (Visio)" }
    "*PROJECTCLIENT*"{ $licensevalue += "Office 365 (PROJECTCLIENT)" }
    "*POWER_BI_STANDARD*"{ $licensevalue += "Office 365 (POWER_BI)" }
    "*DEVELOPERPACK*"{ $licensevalue += "Office 365 (DEVELOPERPACK)" }
    "*PROJECTPROFESSIONAL*"{ $licensevalue += "Office 365 (PROJECTPROFESSIONAL)" }
    "*MCOMEETADV*"{ $licensevalue += "Skype for Business PSTN Conferencing" }
    "*LOCKBOX*"{ $licensevalue += "LOCKBOX" }
    "*EQUIVIO_ANALYTICS*"{ $licensevalue += "EQUIVIO_ANALYTICS"}
    "*AAD_PREMIUM_P2*"{ $licensevalue += "AAD PREMIUM" }
    "*INTUNE_A_VL*"{ $licensevalue += "INTUNE" }
    "*ADALLOM_O365*"{ $licensevalue += "ADALLOM_O365" }
    "*INFOPROTECTION_P2*"{ $licensevalue += "INFOPROTECTION" }
    "*ATP_ENTERPRISE*"{ $licensevalue += "ATP_ENTERPRISE" }
    "*STREAM*"{ $licensevalue += "STREAM" }
    "*ENTERPRISEPREMIUM*"{ $licensevalue += "ENTERPRISEPREMIUM" }
    "*VIDEO_INTEROP*"{ $licensevalue += "VIDEO_INTEROP" }
    "*MCOPSTN2*"{ $licensevalue += "MCOPSTN2" }
    "*FLOW_FREE*"{ $licensevalue += "FLOW_FREE" }
    "*MCOEV*"{ $licensevalue += "MCOEV" }
    "*EMS*"{ $licensevalue += "Enterprise Mobility and Security" }
    "*EXCHANGEENTERPRISE*"{ $licensevalue += "EXCHANGEENTERPRISE" }
    "*RIGHTSMANAGEMENT_ADHOC*"{ $licensevalue += "RIGHTSMANAGEMENT_ADHOC" }
    "*POWERAPPS_VIRAL*"{ $licensevalue += "POWERAPPS_VIRAL" }
    "*VISIOONLINE_PLAN1*"{ $licensevalue += "VISIOONLINE_PLAN1" }
    "*POWER_BI_PRO*"{ $licensevalue += "POWER_BI_PRO" }
    "*MCOPSTN1*"{ $licensevalue += "Domestic Calling Plan" }
    "*POWERFLOW_P2*"{ $licensevalue += "POWERFLOW_P2" }
    "*MCOPSTN_5*"{ $licensevalue += "Domestic Calling Plan (120 Minutes)" }
    "*MCOCAP*"{ $licensevalue += "Common Area Phone" }
    "*MCOPSTNC*"{ $licensevalue += "Communication Credits" }
    "*MCOSTANDARD*"{ $licensevalue += "Skype P2" }
    "*MS_TEAMS_IW*"{ $licensevalue += "Teams Trial" }
    "*PBI_PREMIUM_P1_ADDON*"{ $licensevalue += "PBI_PREMIUM_P1_ADDON" }
    "*WINDOWS_STORE*"{ $licensevalue += "WINDOWS_STORE" }
    "*IDENTITY_THREAT_PROTECTION*"{ $licensevalue += "IDENTITY_THREAT_PROTECTION" }
    "*MICROSOFT_BUSINESS_CENTER*"{ $licensevalue += "MICROSOFT_BUSINESS_CENTER" }
    "*PROJECTPREMIUM*"{ $licensevalue += "PROJECTPREMIUM" }
    "*PHONESYSTEM_VIRTUALUSER*"{ $licensevalue += "PHONESYSTEM_VIRTUALUSER" }
    "*FORMS_PRO*"{ $licensevalue += "FORMS_PRO" }
    "*PBI_PREMIUM_EM2_ADDON*"{ $licensevalue += "PBI_PREMIUM_EM2_ADDON" }
    "*OFFICESUBSCRIPTION*"{ $licensevalue += "OFFICESUBSCRIPTION" }
    "*TEAMS_COMMERCIAL_TRIAL*"{ $licensevalue += "TEAMS_COMMERCIAL_TRIAL" }
    "*POWERAPPS_PER_APP*"{ $licensevalue += "POWERAPPS_PER_APP" }    
    "*MEETING_ROOM*"{ $licensevalue += "MEETING_ROOM" }  
    "*FLOW_PER_USER*"{ $licensevalue += "FLOW_PER_USER" }   
    "*VIRTUAL_AGENT_USL*"{ $licensevalue += "VIRTUAL_AGENT_USL" } 
    "*Win10_VDA_E3*"{ $licensevalue += "Win10_VDA_E3" }  
    "*POWERAPPS_PER_USER*"{ $licensevalue += "POWERAPPS_PER_USER" }  
    "*SPE_F1*"{ $licensevalue += "Microsoft 365 F3" }  
    "*VIRTUAL_AGENT_BASE*"{ $licensevalue += "VIRTUAL_AGENT_BASE" }     
    "*MICROSOFT_REMOTE_ASSIST*"{ $licensevalue += "MICROSOFT_REMOTE_ASSIST" }  
    "*POWERAUTOMATE_ATTENDED_RPA*"{ $licensevalue += "POWERAUTOMATE_ATTENDED_RPA" }
    "*GUIDES_USER*"{$licensevalue += "Dynamics 365 Guides" }
    "*POWERAUTOMATE_UNATTENDED_RPA*"{$licensevalue += "POWERAUTOMATE_UNATTENDED_RPA" }
    "*VIVA_LEARNING*"{$licensevalue += "VIVA_LEARNING" }    
    "*OFFICE365_MULTIGEO*"{$licensevalue += "OFFICE365_MULTIGEO" }  
    "*SPE_E3_RPA1*"{$licensevalue += "Microsoft365E3UnattendedLicense" } 
    "*OFFICE_PROPLUS_DEVICE1*"{$licensevalue += "OFFICE_PROPLUS_DEVICE" }   
    "*DEFENDER_ENDPOINT_P1*"{$licensevalue += "DEFENDER_ENDPOINT_P1" }   
    "*VIVA*"{$licensevalue += "VIVA" }
    "*MTR_PREM_US_CAN*"{$licensevalue += "Teams_Rooms_Premium" }       
    "*DYN365_ENTERPRISE_CUSTOMER_SERVICE*"{$licensevalue += "DYN365_ENTERPRISE_CUSTOMER_SERVICE" }     
    default { $licensevalue = "not found" }
  }
	

  $coll = "" | Select-Object License, ActiveUnits, WarningUnits, ConsumedUnits
	
  $coll.License = $licensevalue
  $coll.ActiveUnits = $_.ActiveUnits
  $coll.WarningUnits = $_.WarningUnits
  $coll.ConsumedUnits = $_.ConsumedUnits
	
  $embody1 += $coll
}

Write-Log -message "fetched Account SKU" -path $log

####################Set CSV headers###############################
$services = $lict.ServicePlans

$csv = @()
$csv1 = $null

foreach ($service in $services)
{
  $servicename = $service.ServicePlanName
  $csv += $servicename
}

$expcsv = $csv | Sort-Object -Unique

$countcs = $expcsv.count

foreach ($cs in $expcsv) { $csv1 += [string]$cs + "," }

$csv2 = $csv1.Substring(0, $csv1.Length - 1)

Add-Content $output "FirstName,LastName,UsageLocation,UserPrincipalName,EmployeeID,Manager,City,State,Country,License,$csv2"

Write-Log -message "Created CSV Header" -path $log
####################loop thru collections########################
Write-Log -message "Loop thru all licensed Users for details" -path $log
$garbagecount = 0
$count=0
Get-mguser -ALL | Select GivenName,Surname,UserPrincipalName,UsageLocation,AssignedLicenses | foreach-object{
  if($garbagecount -eq 10000){$garbagecount =0;[System.GC]::GetTotalMemory($true)| out-null;write-log -message "clearing memory - 10000 records reached" -path $log}
  $garbagecount = $garbagecount + 1
  $user =$null
  $user = $_
  if($user.AssignedLicenses -ne $null){
  $Usr = $UserPrincipalName =$null
  $UserPrincipalName =  $user.UserPrincipalName -replace ",",""
  $FirstName =  $User.GivenName -replace ",",""
  $LastName =  $User.Surname -replace ",",""
  $Manager = $null
  ################Collect all enabled Service Plans#############
  $serviceplancoll = @()
  foreach($al in  $user.AssignedLicenses){
    $coll = "" | Select ServicePlanName
    $fetchskuid = $lict.where{$_.Skuid -eq $al.Skuid}
    $compare = Compare-Object $fetchskuid.ServicePlans.ServicePlanId $al.DisabledPlans
    if($compare){$splan = ($compare | where{$_.SideIndicator -eq "<="}).InputObject
      $serviceplancoll +=$splan
    }
  }
  ####################get serviceplan names#####################
  $serviceplan = @()
  foreach($sp in $serviceplancoll){
    $coll = "" | Select serviceplanid, ServicePlanName, ProvisioningStatus
    $coll.serviceplanid = $sp
    $coll.ServicePlanName = (($lict.ServicePlans).where{$_.ServicePlanId -eq $sp}).ServicePlanName
    $coll.ProvisioningStatus = "Success"
    $serviceplan +=$coll
  }

  $serviceplan = $serviceplan | Select Serviceplanid, @{n="ServicePlanName";e={$_.ServicePlanName | Select -uniq}}, ProvisioningStatus
  #####################################################################
  $Usr = Get-ADuser -filter {UserPrincipalName -eq $UserPrincipalName} -Properties Manager,EmployeeID,City,State,Country
  if($Usr.Manager){$manager = (Get-ADUser $Usr.Manager).userprincipalname}
  $UsageLocation =  $user.UsageLocation -replace ",",""
  $EmployeeID =  $Usr.EmployeeID -replace ",",""
  $City =  $usr.City -replace ",",""
  $State =  $usr.State -replace ",",""
  $Country =  $usr.Country -replace ",",""
   #Write-log -message "Processing..................$UserPrincipalName" -path $log
  $count = $count + 1
  "$count $UserPrincipalName"
  $licenses = @()
  $Userlicenses =  $user.AssignedLicenses.Skuid
  foreach($userlic in $Userlicenses){
    $coll = "" | Select UserLicense
    $coll.UserLicense = $($lict.where{$_.SkuId -eq $userlic}).SkuPartNumber
    $licenses +=$coll
  }
  $licenses = $licenses | select -ExpandProperty UserLicense

  $license = $null
  if ($licenses -notlike $null)
  {
    foreach ($lic in $licenses) { $license += $lic + "," }
    $license = $license.Substring(0, $license.Length - 1)
  }
	
  $provsts = $serviceplan.ProvisioningStatus
  $spcount = $serviceplan.count
	
  [int]$spcount1 = $spcount - 1
  [int]$countcs1 = $countcs - 1
	
  ################Compare the Header with Values################
	
  $provval1 = @(0 .. [int]$countcs1)
	
  for ($j = 0; $j -le [int]$countcs1; $j++) { $provval1[$j] = "Not Active" }
	
  for ($i = 0; $i -le [int]$spcount1; $i++)
  {
    for ($j = 0; $j -le [int]$countcs1; $j++)
    {
      if ($serviceplan[$i].ServicePlanName -eq $expcsv[$j])
      {if ([string]$provsts[$i] -eq "Success") { $provval1[$j] = [string]$provsts[$i] }}
    }
  }
	
  $prov = $null
	
  for ($j = 0; $j -le [int]$countcs1; $j++)
  {$prov += [string]$provval1[$j] + ","}
	
  $prov1 = $prov.Substring(0, $prov.Length - 1)
	
  #####################License values#########################
  $licensevalue = @()
  switch -Wildcard ($license)
  {
    "*DESKLESSPACK*" { $licensevalue += "Office 365 (Plan K1)" }
    "*DESKLESSWOFFPACK*" { $licensevalue += "Office 365 (Plan K2)" }
    "*LITEPACK*" { $licensevalue += "Office 365 (Plan P1)" }
    "*EXCHANGESTANDARD*" { $licensevalue += "Office 365 Exchange Online Only" }
    "*STANDARDPACK*" { $licensevalue += "Office 365 (Plan E1)" }
    "*ENTERPRISEPACK*" { $licensevalue += "Office 365 (Plan E3)" }
    "*ENTERPRISEPACKLRG*" { $licensevalue += "Office 365 (Plan E3)" }
    "*ENTERPRISEWITHSCAL*" { $licensevalue += "Office 365 (Plan E4)" }
    "*STANDARDPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A1) for Students" }
    "*ENTERPRISEPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A3) for Students" }
    "*ENTERPRISEWITHSCAL_STUDENT*" { $licensevalue += "Office 365 (Plan A4) for Students" }
    "*STANDARDPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A1) for Faculty" }
    "*STANDARDWOFFPACKPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A2) for Faculty" }
    "*ENTERPRISEPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A1) for Students" }
    "*STANDARDPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A1) for Students" }
    "*ENTERPRISEPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A3) for Faculty" }
    "*ENTERPRISEWITHSCAL_FACULTY*"{ $licensevalue += "Office 365 (Plan A4) for Faculty" }
    "*ENTERPRISEPACK_B_PILOT*" { $licensevalue += "Office 365 (Enterprise Preview)" }
    "*STANDARD_B_PILOT*" { $licensevalue += "Office 365 (Small Business Preview)" }
    "*VISIOCLIENT*"{ $licensevalue += "Office 365 (Visio)" }
    "*PROJECTCLIENT*"{ $licensevalue += "Office 365 (PROJECTCLIENT)" }
    "*POWER_BI_STANDARD*"{ $licensevalue += "Office 365 (POWER_BI)" }
    "*DEVELOPERPACK*"{ $licensevalue += "Office 365 (DEVELOPERPACK)" }
    "*PROJECTPROFESSIONAL*"{ $licensevalue += "Office 365 (PROJECTPROFESSIONAL)" }
    "*MCOMEETADV*"{ $licensevalue += "Skype for Business PSTN Conferencing" }
    "*LOCKBOX*"{ $licensevalue += "LOCKBOX" }
    "*EQUIVIO_ANALYTICS*"{ $licensevalue += "EQUIVIO_ANALYTICS" }
    "*AAD_PREMIUM_P2*"{ $licensevalue += "AAD PREMIUM" }
    "*INTUNE_A_VL*"{ $licensevalue += "INTUNE" }
    "*ADALLOM_O365*"{ $licensevalue += "ADALLOM_O365" }
    "*INFOPROTECTION_P2*"{ $licensevalue += "INFOPROTECTION" }
    "*ATP_ENTERPRISE*"{ $licensevalue += "ATP_ENTERPRISE" }
    "*STREAM*"{ $licensevalue += "STREAM" }
    "*ENTERPRISEPREMIUM*"{ $licensevalue += "ENTERPRISEPREMIUM" }
    "*VIDEO_INTEROP*"{ $licensevalue += "VIDEO_INTEROP" }
    "*MCOPSTN2*"{ $licensevalue += "MCOPSTN2" }
    "*FLOW_FREE*"{ $licensevalue += "FLOW_FREE" }
    "*MCOEV*"{ $licensevalue += "MCOEV" }
    "*EMS*"{ $licensevalue += "Enterprise Mobility and Security" }
    "*EXCHANGEENTERPRISE*"{ $licensevalue += "EXCHANGEENTERPRISE" }
    "*RIGHTSMANAGEMENT_ADHOC*"{ $licensevalue += "RIGHTSMANAGEMENT_ADHOC" }
    "*POWERAPPS_VIRAL*"{ $licensevalue += "POWERAPPS_VIRAL" }
    "*VISIOONLINE_PLAN1*"{ $licensevalue += "VISIOONLINE_PLAN1" }
    "*POWER_BI_PRO*"{ $licensevalue += "POWER_BI_PRO" }
    "*MCOPSTN1*"{ $licensevalue += "Domestic Calling Plan" }
    "*POWERFLOW_P2*"{ $licensevalue += "POWERFLOW_P2" }
    "*MCOPSTN_5*"{ $licensevalue += "Domestic Calling Plan (120 Minutes)" }
    "*MCOCAP*"{ $licensevalue += "Common Area Phone" }
    "*MCOPSTNC*"{ $licensevalue += "Communication Credits" }
    "*MCOSTANDARD*"{ $licensevalue += "Skype P2" }
    "*MS_TEAMS_IW*"{ $licensevalue += "Teams Trial" }
    "*PBI_PREMIUM_P1_ADDON*"{ $licensevalue += "PBI_PREMIUM_P1_ADDON" }
    "*WINDOWS_STORE*"{ $licensevalue += "WINDOWS_STORE" }
    "*IDENTITY_THREAT_PROTECTION*"{ $licensevalue += "IDENTITY_THREAT_PROTECTION" }
    "*MICROSOFT_BUSINESS_CENTER*"{ $licensevalue += "MICROSOFT_BUSINESS_CENTER" }
    "*PROJECTPREMIUM*"{ $licensevalue += "PROJECTPREMIUM" }
    "*PHONESYSTEM_VIRTUALUSER*"{ $licensevalue += "PHONESYSTEM_VIRTUALUSER" }
    "*FORMS_PRO*"{ $licensevalue += "FORMS_PRO" }
    "*PBI_PREMIUM_EM2_ADDON*"{ $licensevalue += "PBI_PREMIUM_EM2_ADDON" }
    "*OFFICESUBSCRIPTION*"{ $licensevalue += "OFFICESUBSCRIPTION" }
    "*TEAMS_COMMERCIAL_TRIAL*"{ $licensevalue += "TEAMS_COMMERCIAL_TRIAL" }
    "*POWERAPPS_PER_APP*"{ $licensevalue += "POWERAPPS_PER_APP" }    
    "*MEETING_ROOM*"{ $licensevalue += "MEETING_ROOM" }  
    "*FLOW_PER_USER*"{ $licensevalue += "FLOW_PER_USER" } 
    "*VIRTUAL_AGENT_USL*"{ $licensevalue += "VIRTUAL_AGENT_USL" } 
    "*Win10_VDA_E3*"{ $licensevalue += "Win10_VDA_E3" }  
    "*POWERAPPS_PER_USER*"{ $licensevalue += "POWERAPPS_PER_USER" }  
    "*SPE_F1*"{ $licensevalue += "Microsoft 365 F3" }
    "*VIRTUAL_AGENT_BASE*"{ $licensevalue += "VIRTUAL_AGENT_BASE" }   
    "*MICROSOFT_REMOTE_ASSIST*"{ $licensevalue += "MICROSOFT_REMOTE_ASSIST" }  
    "*POWERAUTOMATE_ATTENDED_RPA*"{ $licensevalue += "POWERAUTOMATE_ATTENDED_RPA" }
    "*GUIDES_USER*"{$licensevalue += "Dynamics 365 Guides" }
    "*POWERAUTOMATE_UNATTENDED_RPA*"{$licensevalue += "POWERAUTOMATE_UNATTENDED_RPA" } 
    "*VIVA_LEARNING*"{$licensevalue += "VIVA_LEARNING" } 
    "*OFFICE365_MULTIGEO*"{$licensevalue += "OFFICE365_MULTIGEO" } 
    "*SPE_E3_RPA1*"{$licensevalue += "Microsoft365E3UnattendedLicense" }
    "*OFFICE_PROPLUS_DEVICE1*"{$licensevalue += "OFFICE_PROPLUS_DEVICE" }   
    "*DEFENDER_ENDPOINT_P1*"{$licensevalue += "DEFENDER_ENDPOINT_P1" }   
    "*VIVA*"{$licensevalue += "VIVA" }
    "*MTR_PREM_US_CAN*"{$licensevalue += "Teams_Rooms_Premium" }   
    "*DYN365_ENTERPRISE_CUSTOMER_SERVICE*"{$licensevalue += "DYN365_ENTERPRISE_CUSTOMER_SERVICE" }                
    default { $licensevalue = "not found" }
  }
	
  Add-Content $output "$FirstName,$LastName,$UsageLocation,$UserPrincipalName,$EmployeeID,$Manager,$City,$State,$Country,$licensevalue,$prov1"
  }
}
Write-Log -message "Finished Looping thru all licensed Users - $count" -path $log


############################Send email report###############
$date = Get-Date

$a = "<style>"
$a = $a + "BODY{background-color:peachpuff;}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$a = $a + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$a = $a + "</style>"

$embody1 |
Select-Object @{
  Name       = "License"
  Expression = { $_.License }
}, ActiveUnits, WarningUnits, ConsumedUnits |
ConvertTo-Html -head $a |
Out-File .\LicenseSummary.html
$cont = ".\LicenseSummary.html"

###############################$error reporting################################

if ($error)
{
  Send-Email -SmtpServer $smtpserver -To $erroremail -From $from -Subject "Error Report for Office 365 Licesne Report" -body $error
  Write-Log -Message "Error Report for Office 365 Licesne Report" -path $log  -Severity Error
  Write-Log -Message "$error" -path $log -Severity Error
}else{
Copy-Item -Path $output -Destination $output1
Send-MailMessage -SmtpServer $smtpserver -To $email1 -bcc $erroremail -From $from -Subject "Office 365 License Report - $date"
}
################################################################################
########################Recycle reports & logs##############
Disconnect-MgGraph
Set-Recyclelogs -folderlocation $output1 -limit 730 -Confirm:$false -Verbose
Set-Recyclelogs -foldername logs -limit 60 -Confirm:$false -Verbose
Set-Recyclelogs -foldername Report -limit 60 -Confirm:$false -Verbose

Write-Log -message "Script ............... finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - Office 365 License Report" -Body "Log - Office 365 License Report" -Attachments $log
####################################################################

