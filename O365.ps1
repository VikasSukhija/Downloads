<#	
	===========================================================================
	 Created on:   	12/15/2016 1:32 PM
	 Created by:   	Vikas Sukhija
	 Organization: 	
	 Filename:     	o365.ps1
	 Update:		08/18/2017 (Updated LaunchSPO/RemoveSPO from SHO)
	 Update:		10/24/2018 (included Exchange Online MFA)
	 -------------------------------------------------------------------------
	 O365 shells ALL in One
	===========================================================================
#>
#############################Exchange Online##################
Function LaunchEOL {

$UserCredential = Get-Credential

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

Import-PSSession $Session -Prefix "EOL" -AllowClobber

}



Function RemoveEOL {

$Session = Get-PSSession | where {$_.ComputerName -like "outlook.office365.com"}
Remove-PSSession $Session

}
#############################Exchange MFA Online##################
Function LaunchEOLMFA {

	Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse ).FullName|?{$_ -notmatch "_none_"}|select -First 1)
	$EOLSession = New-ExoPSSession 
	Import-PSSession $EOLSession -Prefix "EOL" -AllowClobber -Verbose
	
	}
	
	Function RemoveEOLMFA {
	
	$Session = Get-PSSession | where {$_.ComputerName -like "outlook.office365.com"}
	Remove-PSSession $Session
	
	}
########################Skype Online#############################
function LaunchSOL
{
	param
	(
		$Domain,
		$UserCredential
	)
	
	Write-Host "Enter Skype Online Credentials" -ForegroundColor Green
	$CSSession = New-CsOnlineSession -Credential $UserCredential -OverrideAdminDomain $Domain -Verbose
	Import-pssession $CSSession -Prefix "SOL" -AllowClobber
}

Function RemoveSOL
{
	
	$Session = Get-PSSession | where { $_.ComputerName -like "admin1a.online.lync.com" }
	Remove-PSSession $Session	
}

#####################Sharepoint Online###############################

function LaunchSPO
{
	param
	(
		$orgName
	)
	
	Write-Host "Enter Sharepoint Online Credentials" -ForegroundColor Green
	$userCredential = Get-Credential
	Connect-SPOService -Url https://$orgName-admin.sharepoint.com -Credential $userCredential
}

Function RemoveSPO
{
	
	disconnect-sposervice
}

#########################Secuirty and Compliance##########################

Function LaunchCOL {

$UserCredential = Get-Credential

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

Import-PSSession $Session -Prefix "COL" -AllowClobber

}



Function RemoveCOL {

$Session = Get-PSSession | where {$_.ComputerName -like "*compliance.protection.outlook.com"}
Remove-PSSession $Session

}
#############################Compliance Online##################
Function LaunchCOLMFA {

	Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA+"\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse ).FullName|?{$_ -notmatch "_none_"}|select -First 1)
	$COLSession = New-EXOPSSession -ConnectionUri 'https://ps.compliance.protection.outlook.com/PowerShell-LiveId'
	Import-PSSession $COLSession -Prefix "COL" -AllowClobber -Verbose
	
	}
	
	Function RemoveCOLMFA {
	
	$Session = Get-PSSession | where {$_.ComputerName -like "*compliance.protection.outlook.com"}
	Remove-PSSession $Session
	
	}
###############################Msonline#########################
function LaunchMSOL
{
	import-module msonline
	Write-Host "Enter MS Online Credentials" -ForegroundColor Green
	Connect-MsolService
}

Function RemoveMSOL
{
	
	Write-host "Close Powershell Window - No disconnect available" -ForegroundColor yellow
}
##################################################################








