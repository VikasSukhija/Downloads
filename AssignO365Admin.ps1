<#	
	.NOTES
	===========================================================================
	 Created with: 	VS Code
	 Created on:   	8/10/2018 1:46 PM
	 Created by:   	Vikas Sukhija
	 Organization: 	
	 Filename:     	AssignO365Admin.ps1
	===========================================================================
	.DESCRIPTION
		This will take Input of UPN from tesxt file and assign the o365 admin role
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [ValidateSet("Helpdesk Administrator",
	"Service Support Administrator",
	"Billing Administrator",
	"Partner Tier1 Support",
	"Partner Tier2 Support",
	"Directory Readers",
	"Exchange Service Administrator",
	"Lync Service Administrator",
	"User Account Administrator",
	"Directory Writers",
	"Company Administrator",
	"SharePoint Service Administrator",
	"Device Users",
	"Device Administrators",
	"Device Join",
	"Workplace Device Join",
	"Compliance Administrator",
	"Directory Synchronization Accounts",
	"Device Managers",
	"Application Administrator",
	"Application Developer",
	"Security Reader",
	"Security Operator",
	"Security Administrator",
	"Privileged Role Administrator",
	"Intune Service Administrator",
	"Cloud Application Administrator",
	"Customer LockBox Access Approver",
	"CRM Service Administrator",
	"Power BI Service Administrator",
	"Guest Inviter",
	"Conditional Access Administrator",
	"Reports Reader",
	"Message Center Reader",
	"Information Protection Administrator")]
    $Role,

    [Parameter(Mandatory = $True, Position = 2)]
    [string]$filePath = $(Read-Host "Enter file path containing UserPrincipalNames")
)

function LaunchMSOL {
    import-module msonline
    Write-Host "Enter MS Online Credentials" -ForegroundColor Green
    Connect-MsolService
}

Function RemoveMSOL {
	
    Write-host "Close Powershell Window - No disconnect available" -ForegroundColor yellow
}
##########################Start the script#######################
Try {
    LaunchMSOL
}
catch {
    $_.exception
    Write-Host "exception occured loading MSOL" -ForegroundColor Yellow
    break;
}

try {
    $users = get-content $filePath

    $users | ForEach-Object {
        $user = $_
        Write-host "Apply $Role to $user" -ForegroundColor green
        Add-MsolRoleMember -RoleMemberEmailAddress $user -RoleName $Role
    }
}
catch {
    $_.exception
    Write-Host "exception occured applring o365 role" -ForegroundColor Yellow
}
######################################################################