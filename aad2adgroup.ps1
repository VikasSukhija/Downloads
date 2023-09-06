<#PSScriptInfo

    .VERSION 1.0

    .GUID 19284df5-9485-4d23-8fdc-91cbdfad8ee4

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
    Created on:   	9/5/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	aad2adgroup.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This will Sync AAD group to AD group

#> 

param (
  [Parameter(Mandatory = $true)]
  [string]$AzureADGroupID,
  [Parameter(Mandatory = $true)]
  [string]$ADgroup,
  [Parameter(Mandatory = $true)]
  [ValidateSet('Sync','ADD','Remove')]
  [string]$Operation,
  [Parameter(Mandatory = $true)]
  [int]$countofchanges,
  [string]$smtpserver,
  [string]$from,
  [string]$erroremail
)
####################Load variables and log##########
$log = Write-Log -Name "aad2adgroup-Log" -folder "logs" -Ext "log"
########################Start Script################
Write-Log -Message "Start script" -path $log
Write-Log -Message "Get Crendetials for Admin ID" -path $log
if(Test-Path -Path ".\Password.xml"){
  Write-Log -Message "Password file Exists" -path $log
}else{
  Write-Log -Message "Generate password" -path $log
  $Credential = Get-Credential 
  $Credential | Export-Clixml ".\Password.xml"
}
#############################################################
$Credential = $null
$Credential = Import-Clixml ".\Password.xml"
##################Connect to Azure####################
try 
{
  Connect-AzureAD -Credential $Credential
  Write-Log -Message "loaded.... AzureAD Module" -path $log
}
catch 
{
  $exception = $_.Exception.Message
  Write-Log -Message "Error loading AzureAD" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error connecting AZUREAD - aad2adgroup" -Body $exception
  exit;
}
#####Start group memberships############################################
try
{
  Write-Log -Message "Start fetching group membership information for AD $ADgroup" -path $log
  $allADgroupmem = Get-ADGroup  $ADgroup -Properties Member | Select-Object -ExpandProperty Member |Get-ADUser |Select-Object -ExpandProperty UserPrincipalName
  Write-Log -Message "fetched group membership information for Source $ADgroup - $($allADgroupmem.count)" -path $log
  Write-Log -Message "Start fetching group membership information for Azure AD Gropup $AzureADGroupID" -path $log
  $allAzureADGroupmem =  Get-AzureADGroupMember -ObjectId $AzureADGroupID -All:$true | Select-Object -ExpandProperty UserPrincipalName
  Write-Log -Message "Finish fetching Destination group membership for Azure AD Gropup $AzureADGroupID - $($allAzureADGroupmem.count)" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message "Error fetching group membership information" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error fetching group membership informatio - aad2adgroup" -Body $exception
  exit
}
###########################Compare the Groups##############################
try
{
  [array]$allADgroupmem+="TESTXXXXVS1"
  [array]$allAzureADGroupmem+="TESTXXXXVS2"
  Write-Log -Message "Start comparing $ADgroup with $AzureADGroupID" -path $log
  $changes = Compare-Object -ReferenceObject $allADgroupmem -DifferenceObject $allAzureADGroupmem -IncludeEqual | 
  Select-Object -Property inputobject, @{
    n = 'State'
    e = {If ($_.SideIndicator -eq "<="){"Removal" } If ($_.SideIndicator -eq "=>"){"Addition" } If ($_.SideIndicator -eq "=="){"Equal"}}
  }
  if($changes)
  {
    $removal = $changes |
    Where-Object -FilterScript {$_.State -eq "Removal" -and $_.inputobject -notlike "TESTXXXXVS*"} |
    Select-Object -ExpandProperty inputobject
    
    $Addition = $changes |
    Where-Object -FilterScript {$_.State -eq "Addition"-and $_.inputobject -notlike "TESTXXXXVS*"} |
    Select-Object -ExpandProperty inputobject
    
    $Equal = $changes |
    Where-Object -FilterScript {$_.State -eq "Equal"-and $_.inputobject -notlike "TESTXXXXVS*"} |
    Select-Object -ExpandProperty inputobject
  }
   #########################Addition and SYNC###################################
  if(($Addition) -and (($Operation -eq "Sync") -or ($Operation -eq "Add")))
  {
    $addcount = $Addition.count
    Write-Log -Message "Adding members to $ADgroup count $addcount" -path $log
    if($addcount -le $countofchanges)
    {
      $Addition | ForEach-Object{
        $amem = $_
        $getaduser = $null
        $getaduser =  Get-ADUser -filter{UserPrincipalName -eq $amem}
        if($getaduser){
          Write-Log -Message "ADD $amem to $ADgroup" -path $log
          Add-ADGroupMember -identity $ADgroup -Members $($getaduser.samaccountname)
        }
        else{
          Write-Log -Message "User $amem not found " -path $log
        }
      }
    }
    else
    {
      Write-Log -Message "ADD count $addcount is more than $countofchanges" -path $log -Severity Error
    }
  }
  #########################Equal and Remove###################################
  if(($Equal) -and ($Operation -eq "Remove"))
  {
    $Equalcount = $Equal.count
    Write-Log -Message "Removing members from $ADgroup count $Equalcount" -path $log
    if($Equalcount -le $countofchanges)
    {
      $Equal | ForEach-Object{
        $amem = $_
        $getaduser = $null
        $getaduser =  Get-ADUser -filter{UserPrincipalName -eq $amem}
        if($getaduser){
          Write-Log -Message "Remove $amem to $ADgroup" -path $log
          Remove-ADGroupMember -identity $ADgroup -Members $($getaduser.samaccountname) -confirm:$false
        }
        else{
          Write-Log -Message "User $amem not found " -path $log
        }
      }
    }
    else
    {
      Write-Log -Message "Remove count $Equalcount is more than $countofchanges" -path $log -Severity Error
    }
  }
  #########################Sync and Remove############################################
  if(($Removal) -and ($Operation -eq "Sync"))
  {
    $Removalcount = $Removal.count
    Write-Log -Message "Removing members from $ADgroup count $Removalcount" -path $log
    if($Removalcount -le $countofchanges)
    {
      $Removal | ForEach-Object{
        $amem = $_
        $getaduser = $null
        $getaduser =  Get-ADUser -filter{UserPrincipalName -eq $amem}
        if($getaduser){
          Write-Log -Message "Remove $amem to $ADgroup" -path $log
          Remove-ADGroupMember -identity $ADgroup -Members $($getaduser.samaccountname) -confirm:$false
        }
        else{
          Write-Log -Message "User $amem not found " -path $log
        }
      }
    }
    else
    {
      Write-Log -Message "Remove count $Removalcount is more than $countofchanges" -path $log -Severity Error
    }
  }
  ###########################################################################################
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message "Error comparing $ADgroup with $AzureADGroupID" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error comparing $ADgroup with $AzureADGroupID - aad2adgroup" -Body $exception
}
Disconnect-AzureAD      
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - aad2adgroup" -Attachments $log
###############################################################################