<#PSScriptInfo

    .VERSION 1.0

    .GUID 5f60cfc9-8427-4392-8fbe-8ba62dac6a15

    .AUTHOR Vikas Sukhija

    .COMPANYNAME techwizard.cloud

    .COPYRIGHT techwizard.cloud

    .TAGS

    .LICENSEURI https://techwizard.cloud/2021/09/24/azuread-application-report/

    .PROJECTURI https://techwizard.cloud/2021/09/24/azuread-application-report/

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES 

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
    https://techwizard.cloud/2021/09/24/azuread-application-report/

    .PRIVATEDATA

    Created with: 	ISE
    Created on:   	9/21/2021 10:40 AM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AzureADApplicationExport.ps1
#>

<# 
    .DESCRIPTION 
    Exctract Azure AD application information
#> 
Param($run="run")
################################Load modules#################
import-module vsadmin
import-module AzureAD
####################Variables/Logs###########################
$log = Write-Log -Name "AzureADApplicationExpirationAlert" -folder "logs" -Ext "log"
$report1 = Write-Log -Name "AzureADApplication-FullReport" -folder "Report" -Ext "csv"
#############################################################
 Write-Log -Message "Start ................Script" -path $log
try
{
  Connect-AzureAD
  Write-Log -Message "Fetching................Applications" -path $log
  $applications = Get-AzureADApplication -All $true
  Write-Log -Message "Fetched Applications - $($applications.count)" -path $log
  Write-Log -Message "Fetching................ServicePrincipals" -path $log
  $servicePrincipals = Get-AzureADServicePrincipal -All $true
  Write-Log -Message "Fetched ServicePrincipals - $($servicePrincipals.count)" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message "exception $exception has occured"  -path $log -Severity Error
  Exit
}
#############################Generate the Report now################
$collection = @()
$applications |  ForEach-Object{
  $owner = (Get-AzureADApplicationOwner -ObjectId $_.ObjectId).UserPrincipalName -join ";"
  $cert = $_.KeyCredentials
  $PasswordCredentials = $_.PasswordCredentials
  $DisplayName = $_.DisplayName
  $ObjectId = $_.ObjectId
  $Appid = $_.AppId
  $sPrincipal= $servicePrincipals | where{$_.appid -eq $Appid}
  $ObjectType = $_.ObjectType
  Write-log -message "Porcessing............$DisplayName" -path $log
  if($cert){
    $cert | ForEach-Object{
      $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $keyId = $_.KeyId
            $certExpirationDate = $_.EndDate
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = $keyId 
            $coll.certExpirationDate = $(get-date $certExpirationDate)
            $coll.SecretKeyID = "NA" 
            $coll.SecretExpirationDate = "NA"
            $coll.SAMLKeyID = "NA" 
            $coll.SAMLCertExpirationDate = "NA"
            $coll.SAMLType = "NA" 
            $coll.SAMLUsage = "NA"
            $collection+=$coll
          }
  }
  elseif($PasswordCredentials){
    $PasswordCredentials | ForEach-Object{
      $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $keyId = $_.KeyId
            $certExpirationDate = $_.EndDate
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = "NA"
            $coll.certExpirationDate = "NA"
            $coll.SecretKeyID = $keyId 
            $coll.SecretExpirationDate = $(get-date $certExpirationDate)
            $coll.SAMLKeyID = "NA" 
            $coll.SAMLCertExpirationDate = "NA"
            $coll.SAMLType = "NA" 
            $coll.SAMLUsage = "NA"
            $collection+=$coll
          }
  }
  elseif($sprincipal.KeyCredentials){
    $sprincipal.KeyCredentials | ForEach-Object{
      $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $keyId = $_.KeyId
            $certExpirationDate = $_.EndDate
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = "NA"
            $coll.certExpirationDate = "NA"
            $coll.SecretKeyID = "NA"
            $coll.SecretExpirationDate = "NA"
            $coll.SAMLKeyID = $keyId 
            $coll.SAMLCertExpirationDate = $(get-date $certExpirationDate)
            $coll.SAMLType = $_.Type
            $coll.SAMLUsage = $_.Usage
            $collection+=$coll
          }
  }
  else{
    $coll = "" | Select DisplayName, ObjectId, AppId , ObjectType, Owner, CertKeyID, certExpirationDate, SecretKeyID, SecretExpirationDate, SAMLKeyID, SAMLCertExpirationDate,SAMLType, SAMLUsage
            $coll.displayname = $DisplayName
            $coll.ObjectId = $ObjectId
            $coll.AppId = $Appid
            $coll.ObjectType = $ObjectType
            $coll.Owner = $owner
            $coll.CertKeyID = "NA"
            $coll.certExpirationDate = "NA"
            $coll.SecretKeyID = "NA" 
            $coll.SecretExpirationDate = "NA"
            $coll.SAMLKeyID = "NA" 
            $coll.SAMLCertExpirationDate = "NA"
            $coll.SAMLType = "NA" 
            $coll.SAMLUsage = "NA"
            $collection+=$coll
  }
}
$collection | export-csv $report1 -NoTypeInformation
Write-Log -Message "Script Finished" -path $log
Disconnect-AzureAD
##########################################################################