<#PSScriptInfo

    .VERSION 1.0

    .GUID f08569d1-4b9c-4ca5-8141-c76a53aa580d

    .AUTHOR Vikas Sukhija

    .COMPANYNAME TechWizard.cloud

    .COPYRIGHT Vikas Sukhija

    .TAGS

    .LICENSEURI https://techwizard.cloud/2021/07/09/powershell-ad-group-to-azure-ad-cloud-only-group-sync/

    .PROJECTURI https://techwizard.cloud/2021/07/09/powershell-ad-group-to-azure-ad-cloud-only-group-sync/

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES 

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES https://techwizard.cloud/2021/07/09/powershell-ad-group-to-azure-ad-cloud-only-group-sync/


    .PRIVATEDATA
    ===========================================================================
    Created with: 	ISE
    Created on:   	7/8/2021 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AD2AzureADGroup.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This can run on schedule and based on selection sync or add group members to AzureAD group

#> 

param (
  [Parameter(Mandatory = $true)]
  [string]$ADgroup,
  [Parameter(Mandatory = $true)]
  [string]$AzureADGroupID,
  [Parameter(Mandatory = $true)]
  [ValidateSet('Sync','ADD','Remove')]
  [string]$Operation,
  [Parameter(Mandatory = $true)]
  [int]$countofchanges
)
#############Functions##############################
function New-FolderCreation
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [string]$foldername
  )
	

  $logpath  = (Get-Location).path + "\" + "$foldername" 
  $testlogpath = Test-Path -Path $logpath
  if($testlogpath -eq $false)
  {
    $null = New-Item -Path (Get-Location).path -Name $foldername -Type directory
  }
}####new folder creation
function Write-Log
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true,ParameterSetName = 'Create')]
    [array]$Name,
    [Parameter(Mandatory = $true,ParameterSetName = 'Create')]
    [string]$Ext,
    [Parameter(Mandatory = $true,ParameterSetName = 'Create')]
    [string]$folder,
    
    [Parameter(ParameterSetName = 'Create',Position = 0)][switch]$Create,
    
    [Parameter(Mandatory = $true,ParameterSetName = 'Message')]
    [String]$message,
    [Parameter(Mandatory = $true,ParameterSetName = 'Message')]
    [String]$path,
    [Parameter(Mandatory = $false,ParameterSetName = 'Message')]
    [ValidateSet('Information','Warning','Error')]
    [string]$Severity = 'Information',
    
    [Parameter(ParameterSetName = 'Message',Position = 0)][Switch]$MSG
  )
  switch ($PsCmdlet.ParameterSetName) {
    "Create"
    {
      $log = @()
      $date1 = Get-Date -Format d
      $date1 = $date1.ToString().Replace("/", "-")
      $time = Get-Date -Format t
	
      $time = $time.ToString().Replace(":", "-")
      $time = $time.ToString().Replace(" ", "")
      New-FolderCreation -foldername $folder
      foreach ($n in $Name)
      {$log += (Get-Location).Path + "\" + $folder + "\" + $n + "_" + $date1 + "_" + $time + "_.$Ext"}
      return $log
    }
    "Message"
    {
      $date = Get-Date
      $concatmessage = "|$date" + "|   |" + $message +"|  |" + "$Severity|"
      switch($Severity){
        "Information"{Write-Host -Object $concatmessage -ForegroundColor Green}
        "Warning"{Write-Host -Object $concatmessage -ForegroundColor Yellow}
        "Error"{Write-Host -Object $concatmessage -ForegroundColor Red}
      }
      
      Add-Content -Path $path -Value $concatmessage
    }
  }
} #Function Write-Log

####################Load variables and log##########
$log = Write-Log -Name "AD2AzureADGroup-Log" -folder "logs" -Ext "log"
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
    e = {If ($_.SideIndicator -eq "=>"){"Removal" } If ($_.SideIndicator -eq "<="){"Addition" } If ($_.SideIndicator -eq "=="){"Equal"}}
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

  if(($Addition) -and (($Operation -eq "Sync") -or ($Operation -eq "Add")))
  {
    $addcount = $Addition.count
    Write-Log -Message "Adding members to $AzureADGroupID count $addcount" -path $log
    if($addcount -le $countofchanges)
    {
      $Addition | ForEach-Object{
        $amem = $_
        $getazureaduser =  Get-AzureADUser -ObjectId $amem
        if($getazureaduser){
          Write-Log -Message "ADD $amem to $AzureADGroupID" -path $log
          Add-AzureADGroupMember -ObjectId $AzureADGroupID -RefObjectId $getazureaduser.objectid
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
  
  if(($Equal) -and ($Operation -eq "Remove"))
  {
    $Equalcount = $Equal.count
    Write-Log -Message "Removing members from $AzureADGroupID count $Equalcount" -path $log
    if($Equalcount -le $countofchanges)
    {
      $Equal | ForEach-Object{
        $amem = $_
        $getazureaduser =  Get-AzureADUser -ObjectId $amem
        if($getazureaduser){
          Write-Log -Message "Remove $amem to $AzureADGroupID" -path $log
          Remove-AzureADGroupMember -ObjectId $AzureADGroupID -MemberId $getazureaduser.objectid
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
  
  if(($Removal) -and ($Operation -eq "Sync"))
  {
    $Removalcount = $Removal.count
    Write-Log -Message "Removing members from $AzureADGroupID count $Removalcount" -path $log
    if($Removalcount -le $countofchanges)
    {
      $Removal | ForEach-Object{
        $amem = $_
        $getazureaduser =  Get-AzureADUser -ObjectId $amem
        if($getazureaduser){
          Write-Log -Message "Remove $amem to $AzureADGroupID" -path $log
          Remove-AzureADGroupMember -ObjectId $AzureADGroupID -MemberId $getazureaduser.objectid
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
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -Message "Error comparing $ADgroup with $AzureADGroupID" -path $log -Severity Error 
  Write-Log -Message $exception -path $log -Severity error
}
Disconnect-AzureAD      
Write-Log -Message "Script Finished" -path $log
###############################################################################