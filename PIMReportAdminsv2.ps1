<#PSScriptInfo

.VERSION 1.0

.GUID de9791d3-4f0c-4cb3-ad88-710daa40ac67

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard.Cloud

.COPYRIGHT TechWizard.cloud

.TAGS 

.LICENSEURI 

.PROJECTURI https://techwizard.cloud/2021/03/21/azure-pim-admin-report-version-2/

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
https://techwizard.cloud/2021/03/21/azure-pim-admin-report-version-2/

#>

<# 

.DESCRIPTION 
 Extract PIM Admin report 

#> 
#####################Functions#####################
Param(
 [string]$TenantID = $(Read-Host "Enter TenantId for your Tenant")
)
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
    #Start-ProgressBar -Title "Creating $foldername folder" -Timer 10
    $null = New-Item -Path (Get-Location).path -Name $foldername -Type directory
  }
}# Function New-FolderCreation
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
$log = Write-Log -Name "PIMAdminReport-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "PIMADMIN-Report" -folder "Report" -Ext "csv"
$collection=@()
########################################################
try
{
  Write-Log -Message "Start...........Script" -path $log 
  Write-Log -Message "Connect to AzureAd" -path $log
  Import-Module -Name AzureADPreview
  Connect-AzureAD
}

catch
{
  $_.Exception
  Write-Log -Message "exception occured generating the PIM Report" -path $log -Severity Error
 }
Write-Log -Message "Start ......... Script" -path $log
$getallPIMadmins = Get-AzureADMSPrivilegedRoleAssignment -ProviderId "aadRoles" -ResourceId $tenantid
$getallPIMadmins | ForEach-Object{
  $error.clear()
  $mcoll = "" | Select-Object UserPrincipalName, RoleID, AssignmentState, StartDateTime, EndDateTime
  $RoleDefinitionId = $_.RoleDefinitionId
  $GetRole = Get-AzureADDirectoryRole | Where-Object{$_.RoleTemplateId -eq $RoleDefinitionId}
  if($error)
  {
    $Roleid = $RoleDefinitionId
    $mcoll.RoleID = $Roleid
    $error.clear()
  }
  else
  {
    $Roleid = $GetRole.DisplayName
    $mcoll.RoleID = $Roleid 
  }    
        
  $Getuser = Get-AzureADUser -ObjectId $_.subjectid
  if($error)
  {
    $userId = $_.subjectid
    $mcoll.UserPrincipalName = $userId
    $error.clear()
  }
  else
  {
    $userId = $Getuser.UserPrincipalName
    $mcoll.UserPrincipalName = $userId
  } 
        
  if(($_.EndDateTime -eq $null) -and ($_.AssignmentState -eq "Active")){$mcoll.AssignmentState = "Permanent"}
  else{$mcoll.AssignmentState = $_.AssignmentState}
  $mcoll.StartDateTime = $_.StartDateTime
  $mcoll.EndDateTime = $_.EndDateTime
  $mcoll
  $collection += $mcoll
}
Disconnect-AzureAD 
#$collection  | Export-Csv $Report1 -NoTypeInformation  #for troubleshooting and chekcing fulle report
$collection |
Where-Object{$_.AssignmentState -ne "Active"} |
Select-Object UserPrincipalName, RoleID, AssignmentState |
Export-Csv $Report1 -NoTypeInformation 

##############################Recycle Logs##########################

Write-Log -Message "Script Finished" -path $log -Severity Information
###############################################################################