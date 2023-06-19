<#PSScriptInfo

.VERSION 1.0

.GUID 5bbe6009-817a-49f5-afb0-c9e328e49131

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard.cloud

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://techwizard.cloud

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES https://techwizard.cloud/


.PRIVATEDATA

#>

<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	5/11/2023  1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	printersreport.ps1
    ===========================================================================
    .DESCRIPTION
    Exatrct Printers report from AD
#>
 
#################logs and variables##########################
$log = Write-Log -Name "printersreport" -folder "logs" -Ext "log"
$Report = Write-Log -Name "Report-printersreport" -folder "Report" -Ext "csv"

#######################get report based on days#########################
Write-Log -Message "Start....................Script" -path $log
try{
  $printers = Get-ADObject -LDAPFilter "(objectCategory=printQueue)" -Properties cn, drivername, location, printername, portname, servername | select portname, cn, drivername, location, printername, servername 
  Write-Log -Message "Fetched all printers - $($printers.count)" -path $log
  $printers | Export-Csv $Report -NoTypeInformation
  Write-Log -Message "Exported report to CSV" -path $log
}
catch{
  $exception = $_.Exception
  Write-Log -Message $exception -path $log -Severity error
}
##########################Script Finished################################
Write-Log -Message "Script Finished" -path $log
#############################completed####################################