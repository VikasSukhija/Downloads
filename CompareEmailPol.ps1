############################################################################
#       	Author: Vikas Sukhija http://msexchange.me
#       	Date: 12/08/2015
#		Update:
#		Reviewed:
#       	Description: Compare Email Policy Exchange
#############################################################################
# Add Exchange Shell...

If ((Get-PSSnapin | where {$_.Name -match "Microsoft.Exchange.Management.PowerShell.E2010"}) -eq $null)
{ Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010}

# Add quest shell
If ((Get-PSSnapin | where {$_.Name -match "Quest.ActiveRoles.ADManagement"}) -eq $null)
{
	Add-PSSnapin Quest.ActiveRoles.ADManagement
}

#######format Date################

$date = get-date -format d
$date = $date.ToString().Replace(“/”, “-”)

$output = ".\" + "EmlcomparisonReport_" + $date + "_.csv"
$Collection = @()
$domain = "domain"
$regex = "^[0-9]*$"
 
#######################

$allmbx = Get-Mailbox -resultsize unlimited | where{$_.CustomAttribute12 -match $regex}

$allmbx | foreach-object {
$firstN = $null
$lastN = $null
 
$qd = get-qaduser $_.samaccountname
$firstN = $qd.FirstName
$lastN = $qd.LastName
$firstN = $firstN.trim()
$firstN = $firstN -replace " ",""
$lastN = $lastN.trim()
$lastN = $lastN -replace " ",""

$Emlpol=$firstN + "." + $lastN + "@" + $domain + "." + "com" ### email policy

#Write-host "Formed email policy address $Emlpol" -foregroundcolor Green

$email = $_.PrimarySmtpAddress

$mbx = ""| select FirstName, Lastname,SamaccountName,Email,Formedaddress
#########compare email policy now

if($email -eq $Emlpol){ 
write-host "email addreses $email is as per email policy $Emlpol" -foregroundcolor Green
}
else{
write-host "email addreses is $email not as per email policy $Emlpol" -foregroundcolor magenta
$mbx.FirstName = $firstN
$mbx.LastName = $lastN
$mbx.SamaccountName = $_.samaccountname
$mbx.Email = $email
$mbx.Formedaddress = $Emlpol
$collection +=$mbx
}

}

#export the collection to csv , change the path accordingly

$Collection | export-csv $output -notypeinformation

###############################################################



