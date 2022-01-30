###############################################################
#			Author: Vikas Sukhija (http://SysCloudPro.com)
#			Date: 8/4/2016
#			Reviewer:
#			updated: 8/11/2016 (created heders/CSV logic)
#			Updated: 8/15/2016 (fixed service status when m,ultiple licenses are there)
#           Updated: 7/4/2017 (fixed when users has e3 as well as e5 with same - multiple subscription)
#			Description: Office 365 users Report
#
###############################################################

$collection = @()

$output = new-item .\office365report.csv -type file -force

$lict = Get-MsolAccountSku
$services = $lict.ServiceStatus

$csv = @()
$csv1=$null

foreach($service in $services){
$provisionstatus = $service.ProvisioningStatus
$servicename = $service.ServicePlan.ServiceName
$csv += $servicename}

$expcsv=$csv | sort -Unique

$countcs= $expcsv.count

foreach($cs in $expcsv){$csv1 += [string]$cs + ","}

$csv2 = $csv1.Substring(0,$csv1.Length-1)

add-content $output "FirstName,LastName,ImmutableId,SignInName,UserPrincipalName,License,$csv2"

##################GEt values from users#####################

$allusers = get-msoluser -ALL

foreach($user in $allusers){

$FirstName = $user.FirstName
$LastName = $user.LastName
$signInname = $user.SignInName
$UserPrincipalName = $user.UserPrincipalName

Write-host "Processing..................$UserPrincipalName" -foregroundcolor green

$ImmutableId=$user.ImmutableId
$licenses = $user.Licenses.AccountSkuId
$license=$null
if($licenses -notlike $null){
foreach($lic in $licenses){$license += $lic + ","}
$license= $license.Substring(0,$license.Length-1)}

$serviceplan = $user.Licenses.ServiceStatus.serviceplan
$provsts = $user.Licenses.ServiceStatus.provisioningstatus
$spcount = $serviceplan.count

[int]$spcount1=$spcount -1
[int]$countcs1=$countcs -1

################Compare the Header with Values################

$provval1=@(0..[int]$countcs1)
for($j=0;$j -le [int]$countcs1;$j++){$provval1[$j]="not found"}


for($i=0;$i -le [int]$spcount1;$i++){
	for($j=0;$j -le [int]$countcs1;$j++){
	if($serviceplan[$i].serviceName -eq $expcsv[$j]){
				if ([string]$provsts[$i] -eq "Success") { $provval1[$j] = [string]$provsts[$i] }
			}
		}
	}
	
$prov=$null
for($j=0;$j -le [int]$countcs1;$j++){
$prov += [string]$provval1[$j] + ","}

$prov1= $prov.Substring(0,$prov.Length-1)

#####################License values#######################################
$licensevalue=@()
switch -Wildcard ($license){
		"*DESKLESSPACK*" { $licensevalue += "Office 365 (Plan K1)" }
		"*DESKLESSWOFFPACK*" { $licensevalue += "Office 365 (Plan K2)" }
		"*LITEPACK*" { $licensevalue += "Office 365 (Plan P1)" }
		"*EXCHANGESTANDARD*" { $licensevalue += "Office 365 Exchange Online Only" }
		"*STANDARDPACK*" { $licensevalue += "Office 365 (Plan E1)" }
		"*ENTERPRISEPACK*" { $licensevalue += "Office 365 (Plan E3)" }
		"*ENTERPRISEPACKLRG*" { $licensevalue += "Office 365 (Plan E3)" }
		"*ENTERPRISEWITHSCAL*" { $licensevalue += "Office 365 (Plan E4)" }
		"*STANDARDPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A1) for Students" }
		"*ENTERPRISEPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A3) for Students" }
		"*ENTERPRISEWITHSCAL_STUDENT*" { $licensevalue += "Office 365 (Plan A4) for Students" }
		"*STANDARDPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A1) for Faculty" }
		"*STANDARDWOFFPACKPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A2) for Faculty" }
		"*ENTERPRISEPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A1) for Students" }
		"*STANDARDPACK_STUDENT*" { $licensevalue += "Office 365 (Plan A1) for Students" }
		"*ENTERPRISEPACK_FACULTY*" { $licensevalue += "Office 365 (Plan A3) for Faculty" }
		"*ENTERPRISEWITHSCAL_FACULTY*"{ $licensevalue += "Office 365 (Plan A4) for Faculty" }
		"*ENTERPRISEPACK_B_PILOT*" { $licensevalue += "Office 365 (Enterprise Preview)" }
		"*STANDARD_B_PILOT*" { $licensevalue += "Office 365 (Small Business Preview)" }
		"*VISIOCLIENT*"{ $licensevalue += "Office 365 (Visio)" }
		"*PROJECTCLIENT*"{ $licensevalue += "Office 365 (PROJECTCLIENT)" }
		"*POWER_BI_STANDARD*"{ $licensevalue += "Office 365 (POWER_BI)" }
		"*DEVELOPERPACK*"{ $licensevalue += "Office 365 (DEVELOPERPACK)" }
		"*PROJECTPROFESSIONAL*"{ $licensevalue += "Office 365 (PROJECTPROFESSIONAL)" }
		"*MCOMEETADV*"{ $licensevalue += "Skype for Business PSTN Conferencing" }
		"*LOCKBOX*"{ $licensevalue += "LOCKBOX" }
		"*EQUIVIO_ANALYTICS*"{ $licensevalue += "EQUIVIO_ANALYTICS" }
		"*AAD_PREMIUM_P2*"{ $licensevalue += "AAD PREMIUM" }
		"*INTUNE_A_VL*"{ $licensevalue += "INTUNE" }
		"*ADALLOM_O365*"{ $licensevalue += "ADALLOM_O365" }
		"*INFOPROTECTION_P2*"{ $licensevalue += "INFOPROTECTION" }
		"*ATP_ENTERPRISE*"{ $licensevalue += "ATP_ENTERPRISE" }
		"*STREAM*"{ $licensevalue += "STREAM" }
		"*ENTERPRISEPREMIUM*"{ $licensevalue += "ENTERPRISEPREMIUM" }
		"*VIDEO_INTEROP*"{ $licensevalue += "VIDEO_INTEROP" }
		"*MCOPSTN2*"{ $licensevalue += "MCOPSTN2" }
		"*FLOW_FREE*"{ $licensevalue += "FLOW_FREE" }
		"*MCOEV*"{ $licensevalue += "MCOEV" }
		default { $licensevalue = "not found" }
	}
	
	add-content $output "$FirstName,$LastName,$ImmutableId,$signInname,$UserPrincipalName,$licensevalue,$prov1"


}
######################################




