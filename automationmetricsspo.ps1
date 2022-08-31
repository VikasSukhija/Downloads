<#PSScriptInfo

.VERSION 1.0

.GUID 99c122a3-ecb4-4cb9-ade2-e6e028d535c1

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard.cloud

.COPYRIGHT

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
    Created on:   	2/9/2022
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	automationmetricsspo.ps1
    ===========================================================================
    .DESCRIPTION
    This Script get metrics data out of Sharepoint lists
#>
[CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    $siteURL,
    [Parameter(Mandatory = $true)]
    $List,
    [Parameter(Mandatory = $true)]
    $startdate,
    [Parameter(Mandatory = $true)]
    $enddate,
    [Parameter(Mandatory = $true)]
    $Tag,
    $report = '.\Report.csv',
    $logrecyclelimit = '60'
  ) 
#####################Load variables and log##########
$log = Write-Log -Name "automationmetrics-Log" -folder "logs" -Ext "log"
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
########################Start Script##############################
Write-Log -Message "Start....................Script" -path $log
 try
  {
    Connect-PnPOnline -Url $siteURL -Credentials $Credential
  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured loading CSOM" -path $log -Severity Error
    break;
  }

try
{
  $reqcoll=@()
  Write-Log -Message "Fetch records for $list" -path $log
  $collection = Get-PnPListItem -List $list -PageSize 5000
  $startdate = get-date $startdate
  $enddate = get-date $enddate
  $NumberofRequests = ($collection | Where{($_["Created"] -gt $startdate) -and ($_["Created"] -lt $enddate)}).count
  Write-Log -Message "Total requests for $list - $NumberofRequests" -path $log
  $coll = "" | Select Name, NumberofRequests, Tag
  $coll.Name = $list
  $coll.NumberofRequests = $NumberofRequests
  $coll.Tag = $Tag
  $reqcoll +=$coll
  $reqcoll | export-csv $report -NoTypeInformation -Append
  Disconnect-PnPOnline
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message $exception -path $log -Severity error
  exit
}
########################Recycle reports & logs#############################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -confirm:$false
Write-Log -Message "Script............Finished" -path $log
########################Script Finished####################################

