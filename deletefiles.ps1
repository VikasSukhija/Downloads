################################################################### 
##        Description:- Delete Files Older Than                  
##                      X-Days Except Certain Subfolders         
##           Author: Vikas Sukhija                                
##           Date: 05-20-2013                                    
##           Created for MS Community request                    
################################################################### 
 
# Specify X days

$days = (get-date).adddays(-30) 

# specify path to root folder 

$path = "C:\folder"

#exclude folders by name

$exclude1 = "exportHierarchy"
$exclude2 = "signature"
 
# format date 
 
$date = get-date -format d 
 
 
# replace \ by - 
 
$date = $date.ToString().Replace("/", "-") 

 
$a= Get-ChildItem  $path | Where{$_.LastWriteTime -lt $days }  

$a | foreach-object{

# expand the condtion if more folders needs to be excluded

if (($_ -notlike $exclude1) -and  ($_ -notlike $exclude2))

{
 
$b = $_

write-host $b

}
 
# specify log path
 
$output =  "C:\Scripts" + "\" + "logs" + "\" + "DEL" + "_" + "$date" + "_log.txt" 
 
Add-content $output "$b log files have been deleted" 

# remove hash file if you want to delete the files
 
#$b | Foreach-Object { del $_.FullName -recurse} 
 

}
########################################################################