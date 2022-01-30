
<#PSScriptInfo

    .VERSION 1.0

    .GUID d0e3dca6-aa3a-4e11-9814-2eed4e65cbe0

    .AUTHOR Vikas Sukhija

    .COMPANYNAME TechWizard.cloud

    .COPYRIGHT Vikas Sukhija

    .TAGS

    .LICENSEURI

    .PROJECTURI  http://techwizard.cloud/2020/09/07/microsoft-teams-number/

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES 

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES  http://techwizard.cloud/2020/09/07/microsoft-teams-number/


    .PRIVATEDATA

#>

<# 

    .DESCRIPTION 
    This will read teams assigned numbers and add to AD attribute 

#> 

param (
  [Parameter(Mandatory = $true)]
  [string]$domain,
  [Parameter(Mandatory = $true)]
  [string]$ADattribute,
  [Parameter(Mandatory = $true)]
  [ValidateSet('True','False')]
  [string]$reportonly,
  [Parameter(Mandatory = $true)]
  [int]$countofchanges
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

function LaunchSOL
{
  param
  (
    [Parameter(Mandatory = $true)]
    $domain,
    [Parameter(Mandatory = $false)]
    $Credential
  )
  Write-Host -Object "Enter Skype Online Credentials" -ForegroundColor Green
  $dommicrosoft = $domain + ".onmicrosoft.com"
  $CSSession = New-CsOnlineSession -Credential $Credential -OverrideAdminDomain $dommicrosoft 
  Import-Module (Import-PSSession -Session $CSSession -AllowClobber) -Prefix SOL  -Global
} #Function LaunchSOL

Function RemoveSOL
{
  $Session = Get-PSSession | Where-Object -FilterScript { $_.ComputerName -like "*.online.lync.com" }
  Remove-PSSession $Session
} #Function RemoveSOL

#####################logs and reports###################
$log = Write-Log -Name "TeamsNumber2ADAttribute-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "TeamsNumber2ADAttribute-Report" -folder "Report" -Ext "csv"
$collection = @()
$credential = Get-Credential
######connect to Skob and import modules ###################################
Write-Log -message "Start..................Script" -path $log
try 
{
  LaunchSOL -Domain $domain -Credential $credential
  Import-Module Activedirectory
  Connect-AzureAD -Credential $credential
  Write-Log -Message "Connected to SKOBOnline and loaded AD module" -path $log
}
catch 
{
  $exception = $($_.Exception.Message)
  Write-Log -Message "$exception" -path $log -Severity Error
  Write-Log -Message "Exception has occured in connecting to SOL or loading AD module" -path $log  -Severity Error
  Exit;
}
##################start processing users##################
try
{
  $allvoiceusers = Get-SOLCsOnlineVoiceUser -First 100000  | Select-Object Name, id, Number, LicenseState, PSTNConnectivity, UsageLocation, EnterpriseVoiceEnabled
  $allvoiceusers = $allvoiceusers  | where{$_.number -ne $null}
  Write-Log -message "Fetched $($allvoiceusers.count) from Teams" -path $log
}
catch
{
  $exception = $($_.Exception.Message)
  Write-Log -Message "$exception" -path $log -Severity Error
  Write-Log -Message "Exception has occured getting details from TEAMS" -path $log  -Severity Error
  Exit;
}

##########ADD UPN to the Collected numbers using azureAD and work with onpremAD#######
Write-Log -message "Fetching and comparing All voice user numbers against AD" -path $log
$tcount=0
ForEach($voiceuser in   $allvoiceusers) 
{
  $mcoll = "" | Select-Object Name, id, UPN, samaccountname, Number,ExistingNumberinAD, PSTNConnectivity, UsageLocation, EnterpriseVoiceEnabled, Status
  $error.clear()
  $azuser = $null
  $getaduser = $null
  $mcoll.Name = $voiceuser.Name
  $mcoll.id = $voiceuser.id

  $azuser = Get-AzureADUser -ObjectId $voiceuser.id
  $mcoll.UPN = $azuser.UserPrincipalName 
  
  Write-Verbose -Message "Processing user..........$($azuser.UserPrincipalName)"
  $voicenumber = "+" + $voiceuser.Number
  
  $mcoll.Number =  $voicenumber
  
  $getaduser = get-aduser -filter {UserPrincipalName -eq $azuser.UserPrincipalName } -properties $ADattribute
  if($getaduser){
    $samaccountname = $getaduser.samaccountname
    $mcoll.samaccountname = $samaccountname 
    $status=$null
    if($getaduser.($ADattribute) -eq $voicenumber)
    {
      #Write-Log -message "Both Numbers match for $($azuser.UserPrincipalName)" -path $log
      $status = "Match"
      $mcoll.Status = $status
      $mcoll.ExistingNumberinAD = $getaduser.($ADattribute)
    }
    else
    {
      #Write-Log -message "Updaing $($azuser.UserPrincipalName) - samaccountname $samaccountname - Number $voicenumber" -path $log
      $status = "UpdateNumber"
      $mcoll.Status = $status
      $mcoll.ExistingNumberinAD = $getaduser.($ADattribute)
    }
  }
  else{
    $mcoll.samaccountname = "Not Found"
    $mcoll.Status = "Not Found"
    $mcoll.ExistingNumberinAD = "Not Found"
  }   
  $mcoll.PSTNConnectivity = $voiceuser.PSTNConnectivity
  $mcoll.UsageLocation = $voiceuser.UsageLocation
  $mcoll.EnterpriseVoiceEnabled = $voiceuser.EnterpriseVoiceEnabled  
  $collection += $mcoll
  $tcount = $tcount +1
  Write-Progress -Activity "Comparing $samaccountname" -status "$status" -percentComplete ( $tcount/$($allvoiceusers.count)*100)
}

if($reportonly -eq "False"){
  $updatenumbers = $collection | where {$_.Status -eq "UpdateNumber"}
  if(($updatenumbers.samaccountname.count -gt 0) -and ($updatenumbers.samaccountname.count -lt $countofchanges)){
    foreach($n in $updatenumbers){
      try{
        $samaccountname = $n.samaccountname
        $vnumber = $n.number
        Set-aduser -identity $samaccountname -Replace @{$ADattribute = "$vnumber"}
        Write-Log -message "Updaing amaccountname $samaccountname - Number $vnumber" -path $log
      }
      catch{
        $exception = $($_.Exception.Message)
        Write-Log -Message "$exception" -path $log -Severity Error
        Write-Log -Message "Exception has occured setting number " -path $log  -Severity Error
      }
    }
  }
  elseif($updatenumbers.samaccountname.count -ge $countofchanges){
    Write-Log -Message "Error has occured setting number - count of changes $($updatenumbers.count) is more than $countofchanges" -path $log  -Severity Error
  }
}

$collection | Export-Csv $Report1 -NoTypeInformation
#########################close sessions and Recycle logs#######################
RemoveSOL
Disconnect-AzureAD
Write-Log -message "Finish..................Script" -path $log

#############################################################################################