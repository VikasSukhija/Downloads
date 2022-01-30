##########################################################################################
#             Authors: Vikas Sukhija,Mahesh Sharma
#             Date: 05/28/2013
#             Description: Script to Output SharePoint Site Owner & Quota information
#                          Output file will then be uploaded to specified SharePoint Site 
##########################################################################################

# Define sharepoint webapp for your Fram (I had two in my farm so defined two webapps)

$webapp1 = "http://team.xxxxxxxx.com"
$webapp2 = "http://sp.xxxxxxxxx.com"

$output1 =  ".\" + "\" + "output" + "\" + "team.html"
$output2 =   ".\" + "\" + "output" + "\" + "sp.html"

# Define the site url & doc library to which this report will be published

$siteurl = "http://team.xxxxxxxx.com/sites/SPDir"
$docLibraryName = "Site List"   


#----ADD Sharepoint Shell-------

If ((Get-PSSnapin | where {$_.Name -match "SharePoint.Powershell"}) -eq $null)
{
	Add-PSSnapin Microsoft.SharePoint.Powershell
}

# All HTML formatting in a single variable to be used with ConvertTo-HTML cmdlet

$HTMLFormat = "<style>"
$HTMLFormat = $HTMLFormat + "BODY{background-color:GainsBoro;}"
$HTMLFormat = $HTMLFormat + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$HTMLFormat = $HTMLFormat + "TH{border-width: 2px;padding: 0px;border-style: solid;border-color: black;background-color:darksalmon}"
$HTMLFormat = $HTMLFormat + "TD{border-width: 2px;padding: 0px;border-style: solid;border-color: black;background-color:LightBlue}"
$HTMLFormat = $HTMLFormat + "</style>"

#Get specified WebApplication --->> Get All sites from specified WebApplication --->> Select URL, Owners & Quo9ta for each site 
#--->> Format output in HTML & save to HTML file


# repeat the code for each web app that you have in the farm


Get-SPWebApplication $webapp1 | Get-SPSite -Limit All | Select URL, Owner, SecondaryContact, 
@{Name="Used Storage"; Expression={"{0:N2} MB" -f ($_.Usage.Storage/1048576)}}, 
@{Name="Storage Quota"; Expression={"{0:N2} MB" -f ($_.Quota.StorageMaximumLevel/1048576)}} | 
ConvertTo-HTML -Head $HTMLFormat  -Body "<H2><Font Size = 4,Color = DarkCyan>SharePoint Farm Site List</Font></H2>" -AS Table | 
Set-Content $output1

# repeated code

Get-SPWebApplication $webapp2 | Get-SPSite -Limit All | Select URL, Owner, SecondaryContact, 
@{Name="Used Storage"; Expression={"{0:N2} MB" -f ($_.Usage.Storage/1048576)}}, 
@{Name="Storage Quota"; Expression={"{0:N2} MB" -f ($_.Quota.StorageMaximumLevel/1048576)}} | 
ConvertTo-HTML -Head $HTMLFormat  -Body "<H2><Font Size = 4,Color = DarkCyan>SharePoint Farm Site List</Font></H2>" -AS Table | 
Set-Content $output2


#Below code will upload the output HTML file to specified SharePoint site
#It will overwrite any existing file with same name

$spWeb = Get-SPWeb $siteurl                            
$localFolderPath = ".\output"                      
$docLibrary = $spWeb.Lists[$docLibraryName]   

$files = ([System.IO.DirectoryInfo] (Get-Item $localFolderPath)).GetFiles() 

$files | ForEach-Object {  
				
          $fileStream = ([System.IO.FileInfo] (Get-Item $_.FullName)).OpenRead()  

    			$contents = new-object byte[] $fileStream.Length  

    			$fileStream.Read($contents, 0, [int]$fileStream.Length);  

   			$fileStream.Close();  

    			$folder = $docLibrary.RootFolder  

    			$spFile = $folder.Files.Add($folder.Url + "/" + $_.Name, $contents, $true)  

    			$spItem = $spFile.Item  


                        } 

##################################################################################################################