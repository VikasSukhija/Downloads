<#PSScriptInfo

.VERSION 1.0

.GUID e7115ef3-3dfe-4543-bc92-9566071e2dca

.AUTHOR SUKHIJV

    Created with: 	VS Code
    Created on:   	9/20/2018 1:46 PM
    Updated on:     2/22/2020
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	ListAllOnedriveSItes.ps1

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI   http://techwizard.cloud/2020/02/23/list-all-onedrive-sites-v2-html-report/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 List All OneDrive Sites along with Usage
 Get all one drive URLs 
 Added Storage usage, Quota and percentage usage 

#> 
#########Load function###############################################
param(
  $orgname = (Read-host "Enter the name of your o365 organization")
)
function Write-Log {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Ext,
        [Parameter(Mandatory = $true)]
        [string]$folder
    )
    
    $log = @()
    $date1 = get-date -format d
    $date1 = $date1.ToString().Replace("/", "-")
    $time = get-date -format t
    
    $time = $time.ToString().Replace(":", "-")
    $time = $time.ToString().Replace(" ", "")
    
    foreach ($n in $name) {
        
        $log += (Get-Location).Path + "\" + $folder + "\" + $n + "_" + $date1 + "_" + $time + "_.$Ext"
    }
    return $log
}
function LaunchSPO
{
  param
  (
    $orgName,
    $cred
  )
	
  Write-Host "Enter Sharepoint Online Credentials" -ForegroundColor Green
  $userCredential = $cred
  Connect-SPOService -Url "https://$orgName-admin.sharepoint.com" -Credential $userCredential
}

Function RemoveSPO
{
	
  disconnect-sposervice
}

#################Check if logs folder is created####
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
$Reportpath  = (Get-Location).path + "\Report" 
$testlogpath = Test-Path -Path $Reportpath
if($testlogpath -eq $false)
{
  New-Item -Path (Get-Location).path -Name Report -Type directory
}
##########################Load variables & Logs####################
$log = Write-Log -Name "process_Onedrive" -folder logs -Ext log
$report = Write-Log -Name "Onedriveurls" -folder Report -Ext html

$onedrivetemplate = "SPSPERS#9"

$collection = @()

##########Start Script main##############

Start-Transcript -Path $log

try
  {
    LaunchSPO -orgName $orgname
  }
  catch
  {
    write-host "$($_.Exception.Message)" -foregroundcolor red
    break
  }
######################SPO Launched, now extract report#######
Write-host "Start generating Onedrive Urls" -ForegroundColor Green
$collection = Get-SPOSite -Template $onedrivetemplate -limit ALL -includepersonalsite $True | Select Owner,Title,Url,StorageUsageCurrent,StorageQuota,StorageQuotaWarningLevel
Write-host "Finished generating Onedrive Urls" -ForegroundColor Green
RemoveSPO
############Format HTML###########
$HTMLFormat = "<style>"
$HTMLFormat = $HTMLFormat + "BODY{background-color:GainsBoro;}"
$HTMLFormat = $HTMLFormat + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$HTMLFormat = $HTMLFormat + "TH{border-width: 2px;padding: 0px;border-style: solid;border-color: black;background-color:darksalmon}"
$HTMLFormat = $HTMLFormat + "TD{border-width: 2px;padding: 0px;border-style: solid;border-color: black;background-color:LightBlue}"
$HTMLFormat = $HTMLFormat + "</style>"
################################

$collection | select  Owner,Title,Url,StorageUsageCurrent,StorageQuota,@{L='Percentage Used';E={"{0:N2}" -f (($_.StorageUsageCurrent/$_.StorageQuota)*100)}},StorageQuotaWarningLevel | ConvertTo-HTML -Head $HTMLFormat -Body "<H2><Font Size = 4,Color = DarkCyan>Onedrive Site URLS</Font></H2>" -AS Table |
Set-Content $report

get-date
Write-Host "Script finished" -ForegroundColor green
Stop-Transcript
######################################################################################