<#PSScriptInfo

    .VERSION 1.0

    .GUID da6d6049-875e-485b-a9c1-4564d327f0cc

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
    Created on:   	10/2/2024 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	BulkRestoreOnedriveFiles.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This script will assit in restoring the files in the OneDrive for Business

#> 
#################Parameters##########################
Param(
  $startDate = "2024-07-20",
  $endDate = "2024-07-25",
  $onedrivesiteURL
)
#################logs and variables##########################
$log = Write-Log -Name "BulkRestoreOnedriveFiles" -folder "logs" -Ext "log"

Write-log -message "Start ......... Script" -path $log

Connect-PnPOnline -Url $onedrivesiteURL -UseWebLogin

$recycleBinItems = Get-PnPRecycleBinItem

$startDate = Get-Date $startDate
$endDate = Get-Date $endDate

$filteredItems = $recycleBinItems | Where-Object { $_.DeletedDate -ge $startDate -and $_.DeletedDate -le $endDate }

$restorefiles = $filteredItems # you can add filter here if you want | where{$_.Title -like "*.csv"}

foreach ($item in  $restorefiles) {
   [string]$id = $item.Id
    Restore-PnPRecycleBinItem -Identity $id -force
    write-log -message "Restored file $($item.Title)" -path $log
}

Write-Log -Message "Script Finished" -path $log
################################################################