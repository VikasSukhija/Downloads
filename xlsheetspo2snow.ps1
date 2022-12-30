<#PSScriptInfo

.VERSION 1.0

.GUID 07718709-8964-45be-8c1f-9ff621912508

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
 xlsheetspo2snow

#> 
<#	
	.NOTES
	===========================================================================
	 Created on:   	6/22/2022 12:01 PM
	 Created by:   	Vikas Sukhija (http://techwizard.cloud)
	 Organization: 	
	 Filename:     	xlsheetspo2snow.ps1

	===========================================================================
	.DESCRIPTION
		Download file from Sharepoint Document Directory and update in Service now Table
#>
param()
###############ADD Logs and Variables#####################
  $log = Write-Log -Name "xlsheetspo2snow" -folder "logs" -Ext "log"
  New-FolderCreation -foldername temp
  $siteURL = 'https Site URL'
  $folderurl = '/Shared Documents/General/xlsheetspo2snow'
  $filename = 'Master_Sheet_xlsheetspo2snow.xlsx'
  $servicenow = 'vikasprod.service-now.com' #snow instance
  $sTable = 'u_ws_master_request_imp_data' #snow table
  $logrecyclelimit = "60"
  $smtpserver = 'smtp.labtest.com'
  $from ='donotreply@labtest.com'
  $erroremail = 'errorslogs@labtest.com'
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
##########Start Script main##############################
  Write-Log -message "Start ......... Script" -path $log
  try
  {
    Connect-PnPOnline -Url $siteURL -Credentials $Credential
    New-ServiceNowSession -Url $servicenow -Credential $Credential
  }
  catch
  {
    $($_.Exception.Message)
    Write-log -message "exception has occured loading CSOM" -path $log
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - xlsheetspo2snow" -Body $($_.Exception.Message)
    break;
  }
	
  try
  {   
    $Files=Get-PnPFolderItem -FolderSiteRelativeUrl $folderurl -ItemType File
    Foreach($file in $Files){
    Write-log -message "Download file $($file.ServerRelativeUrl)" -path $log
    Get-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Path .\temp -FileName $file.Name -AsFile
    } 
    $getfile = Get-ChildItem $((get-location).path + "\temp") | where{$_.Name -eq $filename}
    Write-log -message "Importing file - $($getfile.FullName)" -path $log
    $data = Import-Excel $getfile.FullName
    Write-log -message "Data count - $($data.count)" -path $log
    Write-log -message "Non Null count $(($data | where{$_.'Account ID' -ne $null}).count)"  -path $log
    $data | where{$_.'Account ID' -ne $null} | ForEach-Object{
    $accountid = $_.'Account ID'
    $accountname = $_.'Account name'
    $CloudHealthADGroup = $_.'CloudHealth AD Group'
    $CostCentertoChargeBack = $_.'CostCenter to ChargeBack'
    $email = $_.Email
    $PrimaryuserID = $_.'Primary user ID'
    $CurrentStatus = $_.'Current Status'
 $params =@{'u_account_id' = $accountid
            'u_account_name' =  $accountname
            'u_cloudhealth_ad_group' = $CloudHealthADGroup
            'u_costcenter_to_chargeback' = $CostCentertoChargeBack
            'u_email' = $email
            'u_primary_user_id' = $PrimaryuserID
            'u_current_status' = $CurrentStatus
            }
    Write-Log -message "$accountid - $accountname - $CloudHealthADGroup - $CostCentertoChargeBack - $email - $PrimaryuserID" -path $log
    New-ServiceNowRecord -Table $sTable -Values $params

    }
    
    if($error){
    Write-log -message "Error has occured" -path $log
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - xlsheetspo2snow" -Body $error[0].tostring()
    }
  }
  catch
  {
    Write-log -message "$($_.Exception.Message)" -path $log
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - List Reading xlsheetspo2snow" -Body $($_.Exception.Message)
    Break;
  }	
  Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
  Set-Recyclelogs -foldername "temp" -limit 0 -Confirm:$false
  Write-log -message "Script finished" -path $log
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - xlsheetspo2snow" -Attachments $log
  Disconnect-PnPOnline
  ###################################################################################
