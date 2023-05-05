<#PSScriptInfo

.VERSION 1.0

.GUID 6403bab7-e73a-43c2-bba4-7d9bc626b2cc

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
 bulkupdateprimaryuser

#> 

<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	4/25/2023  1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	bulkupdateprimaryuser.ps1
    ===========================================================================
    .DESCRIPTION
    This will chnage the primary user for a Device base don User request
#>
param(
$csvfilepath
)

$data = import-csv $csvfilepath
#################logs and variables##########################
$log = Write-Log -Name "bulkupdateprimaryuser" -folder "logs" -Ext "log"
$Report = Write-Log -Name "bulkupdateprimaryuser" -folder "Report" -Ext "csv"

##################get-credentials##########################
$TenantName = "TenantName"
$MgGClientID = "MgGClientID"
$ThumbPrint= "certthumbprint"
#######################intune functions from GitHUB Intune repo#########################
function Get-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This lists the Intune device primary user
.DESCRIPTION
This lists the Intune device primary user
.EXAMPLE
Get-IntuneDevicePrimaryUser
.NOTES
NAME: Get-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    [string] $deviceId
)
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
	$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        
        #$primaryUser = Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Bearer $($accesstoken)"} -Method Get
        $primaryUser = Invoke-MgGraphRequest -Uri $uri -Method Get

        return $primaryUser.value."id"
        
	} catch {
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Get-IntuneDevicePrimaryUser error"
	}
}

function Set-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This updates the Intune device primary user
.DESCRIPTION
This updates the Intune device primary user
.EXAMPLE
Set-IntuneDevicePrimaryUser
.NOTES
NAME: Set-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$IntuneDeviceId,
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$userId
)
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref"

    try {
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

        $userUri = "https://graph.microsoft.com/$graphApiVersion/users/" + $userId

        $id = "@odata.id"
        $JSON = @{ $id="$userUri" } | ConvertTo-Json -Compress

        #Invoke-RestMethod -Uri $uri -Headers @{Authorization = "Bearer $($accesstoken)"} -Method Post -Body $JSON -ContentType "application/json"
        Invoke-MgGraphRequest -Uri $uri -Method POST -body $JSON -ContentType "application/json"

	} catch {
		$ex = $_.Exception
		$errorResponse = $ex.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($errorResponse)
		$reader.BaseStream.Position = 0
		$reader.DiscardBufferedData()
		$responseBody = $reader.ReadToEnd();
		Write-Host "Response content:`n$responseBody" -f Red
		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
		throw "Set-IntuneDevicePrimaryUser error"
	}

}

########################################################################
try
  {
    Write-Log -Message "Start ......... Script" -path $log
    Connect-MgGraph -ClientId $MgGClientID -CertificateThumbprint $ThumbPrint -TenantId $TenantName
    Select-MgProfile -Name "beta"
    Write-Log -message "Loaded All Modules" -Path $log
  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured  - bulkupdateprimaryuser" -path $log -Severity Error
    break;
  }

  $collection=@()
  foreach($i in $data){
  $mcoll = "" | Select DeviceName, DeviceID, CurrentPrimaryUser, CurrentPrimaryUserFromFile, NewPrimaryUser, Status
  $DeviceName = $NewPrimaryUser = $CurrentPrimaryUserFromFile = $getdevice = $primaryuserid = $getnewprimaryuser = $null
  $DeviceName = $i.DeviceName.trim()
  $NewPrimaryUser = $i.NewPrimaryUser.trim()
  $CurrentPrimaryUserFromFile = $i.CurrentPrimaryuser.trim()
  Write-log -message "DeviceName - $DeviceName" -path $log
  Write-log -message "NewPrimaryUser - $NewPrimaryUser" -path $log
  Write-log -message "PrimaryUserFromFile - $CurrentPrimaryUserFromFile" -path $log
  $mcoll.DeviceName =  $DeviceName 
  $mcoll.NewPrimaryUser = $NewPrimaryUser
  $mcoll.CurrentPrimaryUserFromFile = $CurrentPrimaryUserFromFile
  $getdevice = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'"
  if($getdevice.id.count -gt 1){
          $getdevice = $getdevice | sort -Descending -Property lastsyncdatetime
          $getdevice = $getdevice[0]
  }
  Write-log -message "DeviceID - $($getdevice.id)" -path $log
  $mcoll.DeviceID = ($getdevice.id)
  if($getdevice){
            $primaryuserid = Get-IntuneDevicePrimaryUser -deviceId $($getdevice.id)
            if($primaryuserid){
            $getprimaryuser = Get-MgUser -UserId $primaryuserid
            Write-log -message "CurrentPrimaryUser - $($getprimaryuser.UserPrincipalName)" -path $log
            $mcoll.CurrentPrimaryUser = $($getprimaryuser.UserPrincipalName)
            }
            else{
            Write-log -message "CurrentPrimaryUser - Not Set" -path $log
            $mcoll.CurrentPrimaryUser = "Not Set"

            }
            Write-Log -message "Update Current Primary user to $NewPrimaryUser" -path $log
            $getnewprimaryuser = Get-MgUser -UserId $NewPrimaryUser
            Set-IntuneDevicePrimaryUser -IntuneDeviceId $($getdevice.id) -userId $($getnewprimaryuser.id)
            if($error){
            Write-Log -message "Error - $error" -path $log
            $mcoll.status = "error"
            $error.clear()
            }
            else{
            Write-Log -message "Success - Setting Primary User to $NewPrimaryUser" -path $log
            $mcoll.status = "Success"

            }
  }
  else{
  Write-log -message "DeviceID - Device Not Found" -path $log
  $mcoll.DeviceID = "Not Found"
  }
  $collection+=$mcoll
  }
  $collection | Export-Csv $Report -NoTypeInformation
##########################Script Finished###################################################

Write-Log -Message "Script Finished" -path $log
Disconnect-MgGraph
#############################completed########################################################