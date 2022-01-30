######################################################################################
Param(
  [string]$user
)

function checkuserDN ($usersm) 
{ 
 
$Search = New-Object DirectoryServices.DirectorySearcher([ADSI]"") 
$Search.filter = "(&(objectCategory=user)(objectClass=user)(sAMAccountName=$usersm))" 
$findusr=$Search.Findall() 

if ($findusr.count -gt 1)
      {    
            $count = 0
            foreach($i in $findusr)
            {
                  write-host $count ": " $i.path
                  $count = $count + 1
		write-host "multiple matches found"
            }

       exit
      }
      elseif ($findusr.count -gt 0)
      {
            return $findusr[0].path
      }
      else
      {
      write-host "no match found"

      }
}

if($user -like $null)
{
"Pls use script as - chkusrdn.ps1 usersamacountname"
}
else
{
checkuserDN $user

}
###################################################################################