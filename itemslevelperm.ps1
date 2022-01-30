####################################################################
#			Author: Vikas Sukhija
#			Date: 07/10/2015
#			Description : Provide item level permissions
#			on Sharepoint List
#
####################################################################

########################ADD SP Shell #############################

If ((Get-PSSnapin | where {$_.Name -match "SharePoint.Powershell"}) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.Powershell
}

############################Define Variables ##################

$site  = "http://spsharepoint/sites/nworkflow"
$listname = "Authorization List"
$userid = "Lab\sakiv"
$permissionLevel = "Read"

#####Get list items & role defs #####

$web = get-spweb $site
$list = $web.lists[$listname]
$items = $list.items
$permission = $web.RoleDefinitions[$permissionLevel]
$user = $web.siteusers[$userid]

####apply individual permissions #####

$items | foreach-object{

if ($_.HasUniqueRoleAssignments -eq $True){

$idstring = $_.ID.tostring()

Write-host ""item Number********" + $idstring" -foregroundcolor green

$permlevels = $_.RoleAssignments

$roles = $permlevels |select -expandproperty RoleDefinitionBindings
$rolescollect=$null;$rolescollect=@();
$roles | foreach-object{ $rolescollect += $_.Name}


$permlevel = $permlevels | where {$_.Member.Name -eq $user.Name}

	if (($permlevel -eq $NULL) -and ($rolescollect -notcontains "$permissionLevel"))  {

	$setp = new-object Microsoft.SharePoint.SPRoleAssignment($user)
 	$setp.RoleDefinitionBindings.add($permission) 
	$permlevels.add($setp)
	Write-host "$permissionLevel added to $userid on $idstring" -foregroundcolor blue
	}

	elseif (($permlevel -eq $NULL) -and ($rolescollect -contains "$permissionLevel")) {

	$setp = new-object Microsoft.SharePoint.SPRoleAssignment($user)
 	$setp.RoleDefinitionBindings.add($permission)
	$permlevels.Add($setp)
	Write-host "updated permission $permissionlevel for $userid on $idstring" -foregroundcolor magenta
	}


}

}
$web.Dispose()

#####################################################################