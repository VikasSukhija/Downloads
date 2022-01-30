<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	10/10/2019 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	http://techcloud.wizard
    Filename:     	PIMReportAdmins.ps1
    ===========================================================================
    .DESCRIPTION
    This script will extract the Report of Admins in PIM
    Requirements:
    Graph Module 
    MSonline module
#>
param (
  [string]$AppName = $(Read-Host "Enter Name of the APP that you have registered in AzureAD"),
  [string]$Tenant = $(Read-Host "Enter Name of the Tenant"),
  [string]$clientId = $(Read-Host "Enter Client ID of the APP that you have registered in AzureAD"),
  $ClientSecret = $(Read-Host -assecurestring "Please enter Client secret for the APP"),
  [string]$msolaccount = $(Read-Host "Enter account to connect to msonile module"),
  $msolpassword = $(Read-Host -assecurestring "Please enter msol account password"),
  [string]$smtpserver = $(Read-Host "Enter SMTP Server"),
  [string]$from = $(Read-Host "Enter From Address"),
  [string]$erroremail = $(Read-Host "Enter Address for Report and Errors")
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
}

function LaunchMSOL {
        param
        (
            $UserCredential
        )
        import-module msonline
        Write-Host "Enter MS Online Credentials" -ForegroundColor Green
        Connect-MsolService -Credential $UserCredential
    }
	
    Function RemoveMSOL {
		
        Write-host "Close Powershell Window - No disconnect available" -ForegroundColor yellow
    }
#################Check if logs folder is created####
$logpath  = (Get-Location).path + "\logs" 
$testlogpath = Test-Path -Path $logpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating logs folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Logs -Type directory
}
$Reportpath  = (Get-Location).path + "\Report" 
$testlogpath = Test-Path -Path $Reportpath
if($testlogpath -eq $false)
{
  Start-ProgressBar -Title "Creating Report folder" -Timer 10
  New-Item -Path (Get-Location).path -Name Report -Type directory
}
####################Load variables and log##########
$log = Write-Log -Name "PIMAdminReport-Log" -folder "logs" -Ext "log"
$Report1 = Write-Log -Name "PIMADMIN-Report" -folder "Report" -Ext "csv"

$Resource = "privilegedRoleAssignments"
$graphApiVersion = "beta"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
$collection = @()

#######################################################

Write-log -Message "Start .........Script" -path $log
try{
  $Credential1 = New-Object System.Management.Automation.PSCredential -ArgumentList $clientId, $ClientSecret
  $Credential2 = New-Object System.Management.Automation.PSCredential -ArgumentList $msolaccount, $msolpassword
  Write-log -Message "loading credentials" -path $log
  }
  catch{
      $_.Exception
    Write-log -Message "exception has occured loading credentials" -path $log
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error loading credentials PIMADMINs Report" -Body $($_.Exception.Message)
    exit;
  }

try
  {
     Import-Module -name 'PSMSGraph'
     LaunchMSOL -UserCredential  $Credential2
     Write-log -Message "loading Graph and MSOL" -path $log
  }
  catch
  {
    $_.Exception
    Write-log -Message "exception has Loading graph and MSOL" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error exception has Loading graph and MSOL PIMADMINs Report" -Body $($_.Exception.Message)
    exit;
  }

##############Check if token is present else prompt################
$Accesstokenpath  = (Get-Location).path + "\AccessToken.XML" 
$testaccesstpath = test-path -Path $Accesstokenpath
if($testaccesstpath -eq $false){
$GraphAppParams = @{
    Name = $appname
    ClientCredential = $Credential1
    RedirectUri = 'https://localhost/'
    Tenant = $tenant
}
$GraphApp = New-GraphApplication @GraphAppParams
$AuthCode = $GraphApp | Get-GraphOauthAuthorizationCode 
$GraphAccessToken = $AuthCode | Get-GraphOauthAccessToken -Resource 'https://graph.microsoft.com'
$GraphAccessToken | Export-GraphOAuthAccessToken -Path $Accesstokenpath

} #############Access token generated############

  try{
    $GraphAccessToken =  Import-GraphOAuthAccessToken -Path $Accesstokenpath
    $GraphAccessToken | Update-GraphOAuthAccessToken -Force #refresh token
    $graphdata = Invoke-GraphRequest -AccessToken $GraphAccessToken -Uri $uri -Method GET
    $fetchallpimadmins = ConvertFrom-Json $graphdata.Result.Content
    $getallPIMadmins = $fetchallpimadmins.value
    $getallPIMadmins | ForEach-Object{
      $mcoll = "" | Select UserPrincipalName, RoleID,isElevated
      $userid = $_.userid
      $roleid = $_.RoleID
      $msoluserid = Get-MsolUser -ObjectId $userid | Select UserPrincipalName
      $msolroleid = Get-MsolRole -ObjectId $roleid | Select Name
      $mcoll.UserPrincipalName = $msoluserid.UserPrincipalName
      $mcoll.RoleID = $msolroleid.Name
      $mcoll.isElevated = $_.isElevated
      $mcoll
      $collection+=$mcoll
    } 
    $collection | Export-Csv $Report1 -NoTypeInformation 
    $GraphAccessToken | Export-GraphOAuthAccessToken -Path $Accesstokenpath #export the token again
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "PIM Report - Elevated Admins" -Attachments $Report1
  }
  
  catch{
    $_.Exception
    Write-log -Message "exception occured generating the PIM Report" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error exception occured generating the PIM Report" -Body $($_.Exception.Message)
  }

##############################Recycle Logs##########################
Write-Log -Message "Recycle Logs" -path $log -Severity Information
$path1 = (Get-Location).path + "\report"
$path2 = (Get-Location).path + "\logs" 

$limit = (Get-Date).AddDays(-60) #for report recycling
Get-ChildItem -Path $path1 |
Where-Object {$_.CreationTime -lt $limit} |
Remove-Item -recurse -Force

Get-ChildItem -Path $path2 |
Where-Object {$_.CreationTime -lt $limit} |
Remove-Item -recurse -Force

Write-Log -Message "Script Finished" -path $log -Severity Information
Send-MailMessage -SmtpServer $SmtpServer -From $From -To $erroremail -Subject "Transcript Log - PIMADMINs Report" -Body "Transcript Log - PIMADMINs Report" -Attachments $log
###############################################################################