<#	
    .NOTES
    ===========================================================================
    Created on:   	6/22/2022 12:01 PM
    Created by:   	Vikas Sukhija (http://techwizard.cloud)
    Organization: 	
    Filename:     	DownloadSPOFiles.ps1

    ===========================================================================
    .DESCRIPTION
    Download file from Sharepoint Document Directory using PNP
#>
param(
  $siteURL,
  $folderurl,
  $destination
)

###############ADD Logs and Variables#####################
$log = Write-Log -Name "Downloadfiles_SPO" -folder "logs" -Ext "log"
New-FolderCreation -foldername temp
$logrecyclelimit = "60"
#####################userid/password##########################
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
  
try
{
  Connect-PnPOnline -Url $siteURL -Credentials $Credential
}
catch
{
  Write-Log -message "exception has occured - $($_.Exception.Message)" -path $log
  break;
}
	
try
{   
  $Files = Get-PnPFolderItem -FolderSiteRelativeUrl $folderurl -ItemType File
  Foreach($file in $Files)
  {
    Write-Log -message "Download file $($file.ServerRelativeUrl)" -path $log
    Get-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Path .\temp -Filename $file.Name -AsFile
  } 
  Write-Log -message "Move files to $destination" -path $log
  Get-ChildItem -Path $((Get-Location).path + '\temp') | ForEach-Object -Process {
    Move-Item -Path $_.FullName -Destination $destination
  }
  if($error)
  {
    Write-Log -message "Error $error has occured" -path $log
  }
}
catch
{
  Write-Log -message "$($_.Exception.Message)" -path $log
  Break
}	
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -message "Script finished" -path $log
###################################################################################
