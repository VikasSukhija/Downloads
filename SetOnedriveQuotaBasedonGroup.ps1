<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	4/20/20201:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	SetOnedriveQuotaBasedonGroup.ps1
    ===========================================================================
    .DESCRIPTION
    This script will get ad group membesr and upadte their onedrive quota
#>
param (
  [string]$Group = $(Read-Host "Enter the AD group to Process"),
  [string]$Quota = $(Read-Host "Enter the quota that you want to set"),
  [string]$Quotawarning = $(Read-Host "Enter the quota warning that you want to set"),
  [string]$Org = $(Read-Host "Enter organization Name, example: if your tenant is testlab.onmicrosoft.com than type testlab"),
  $runfromfile = $(Read-Host "Run from file - Yes or No")
)

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
    [String]$Message,
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
	
      foreach ($n in $Name)
      {$log += (Get-Location).Path + "\" + $folder + "\" + $n + "_" + $date1 + "_" + $time + "_.$Ext"}
      return $log
    }
    "Message"
    {
      $date = Get-Date
      $concatmessage = "|$date" + "|   |" + $Message +"|  |" + "$Severity|"
      switch($Severity){
        "Information"{Write-Host -Object $concatmessage -ForegroundColor Green}
        "Warning"{Write-Host -Object $concatmessage -ForegroundColor Yellow}
        "Error"{Write-Host -Object $concatmessage -ForegroundColor Red}
      }
      
      Add-Content -Path $path -Value $concatmessage
    }
  }
} #Function Write-Log

function Start-ProgressBar
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    $Title,
    [Parameter(Mandatory = $true)]
    [int]$Timer
  )
	
  For ($i = 1; $i -le $Timer; $i++)
  {
    Start-Sleep -Seconds 1;
    Write-Progress -Activity $Title -Status "$i" -PercentComplete ($i /100 * 100)
  }
} #Function Start-ProgressBar

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
} #Function LaunchSPO

Function RemoveSPO
{
	
  disconnect-sposervice
} #Function RemoveSPO
#################Check if logs folder is created##################
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
####################Load variables and log#########################
$log = Write-Log -Name "SetonedriveQuota-Log" -folder "logs" -Ext "log"
$outmem =  Write-Log -Name "ADgroupMembersextract" -folder "logs" -Ext "log"

#####connect to PNP and Ad module##################################
 try {
    Import-Module -name ActiveDirectory
    $cred = Get-Credential
    $url = "https://" + "$org" + "-admin.sharepoint.com/"
    Write-Log -Message "Admin URL: $url" -path $log 
    Connect-PnPOnline -Url $url -Credential $cred
    LaunchSPO -orgName $org -cred $Cred
    Write-Log -Message "Loaded AD, PNP and SPO Module" -path $log 
 }
    catch 
    {
      $exception = $($_.Exception.Message)
      Write-Log -Message "$exception" -path $log -Severity Error
      Write-Log -Message "Exception has occured in AD, PNP and SPO Module" -path $log  -Severity Error
      Exit;
    }
    
 #######################Fetch the AD group##########################
 if($runfromfile -eq "Yes"){
 try{
 [string]$textfilepath = $(Read-Host "Enter the text file Name present in current directory")
 $getadgpmems = get-content $textfilepath
 }
 catch 
    {
      $exception = $($_.Exception.Message)
      Write-Log -Message "$exception" -path $log -Severity Error
      Write-Log -Message "Exception has occured Fetching csv file" -path $log  -Severity Error
     Start-ProgressBar -Title "Invalid Option selected" -Timer 10
     Write-Log -Message "Script Finished" -path $log
     Write-Log -Message "Disconnecting powershell sessions to SPO/PNP" -path $log
     RemoveSPO
     Disconnect-PnPOnline
      Exit;
    }

 }
 elseif($runfromfile -eq "No"){
 try{
   $getadgpmems = Get-ADGroup -Identity $Group -Properties member | Select-Object -ExpandProperty member | get-aduser | Select-Object -ExpandProperty userprincipalname
   $getadgpmems | out-file $outmem
   Write-Log -Message "Fetched all members of AD group $Group" -path $log 
 }
 
     catch 
    {
      $exception = $($_.Exception.Message)
      Write-Log -Message "$exception" -path $log -Severity Error
      Write-Log -Message "Exception has occured Fetching membersof AD group $Group" -path $log  -Severity Error
     Start-ProgressBar -Title "Invalid Option selected" -Timer 10
     Write-Log -Message "Script Finished" -path $log
     Write-Log -Message "Disconnecting powershell sessions to SPO/PNP" -path $log
     RemoveSPO
     Disconnect-PnPOnline
      Exit;
    }
    }
 else{
     Write-Log -Message "Invalid Option selected" -path $log -Severity Error
     Start-ProgressBar -Title "Invalid Option selected" -Timer 10
     Write-Log -Message "Script Finished" -path $log
     Write-Log -Message "Disconnecting powershell sessions to SPO/PNP" -path $log
     RemoveSPO
     Disconnect-PnPOnline

     exit

    }
 ##################################################################
 $getadgpmems | ForEach-Object{
   $error.Clear()
   $upn = $_
   $onedriveurl = $null
   $onedriveurl = Get-PnPUserProfileProperty -Account $upn | Select-Object -ExpandProperty PersonalUrl
   Write-Log -Message "Onedriveurl: $onedriveurl - UserPrinCipalName: $upn" -path $log 
   if($onedriveurl){
   $onedriveurl = $onedriveurl.Substring(0,$onedriveurl.Length-1) #remove /
   Set-SPOSite -Identity $onedriveurl -StorageQuota $Quota -StorageQuotaWarningLevel $Quotawarning
   if($error)
   {
   Write-Log -Message "Error processing quota for $upn - $onedriveurl" -path $log -Severity Warning
   }
   else{
   Write-Log -Message "Success processing quota for $upn - $onedriveurl" -path $log

   }

   }
 }
 #############################Disconnect Sessions#####################
 Write-Log -Message "Script Finished" -path $log
 Write-Log -Message "Disconnecting powershell sessions to SPO/PNP" -path $log
 RemoveSPO
 Disconnect-PnPOnline

 ########################################################################