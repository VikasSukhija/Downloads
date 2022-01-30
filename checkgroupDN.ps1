######################################################################################
Param(
  [string]$Group
)

function checkgroupDN ($Group) 
{ 
 
$Search = New-Object DirectoryServices.DirectorySearcher([ADSI]"") 
$Search.filter = "(&(objectCategory=group)(objectClass=group)(sAMAccountName=$Group))" 
$findgrp=$Search.Findall() 

if ($findgrp.count -gt 1)
      {    
            $count = 0
            foreach($i in $findgrp)
            {
                  write-host $count ": " $i.path
                  $count = $count + 1
		  write-host "multiple matches found"
            }

       exit
      }
      elseif ($findgrp.count -gt 0)
      {
            return $findgrp[0].path
      }
      else
      {
      write-host "no match found"

      }
}

if($Group -like $null)
{
"Pls use script as - checkgroupDN.ps1 groupsamacountname"
}
else
{
checkgroupDN $Group

}
###################################################################################