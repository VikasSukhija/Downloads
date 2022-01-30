<#	
	.NOTES
	===========================================================================
	 Created on:   	8/02/2018 1:46 PM
     Initial Author : K Phani Kumar
	 Author/Reviewer: Vikas Sukhija (http://SysCloudPro.com)
	 Organization: 	
	 Filename:     	ServerInstallationCheck.ps1
	===========================================================================
	.DESCRIPTION
    This script generates the report about the details and status of parameters like Server Hardware, OS, Drives, 
    Hotfixes, Admin Group Members, Current OU of Server etc.
#>
# Functions Used in Script
Function Get-LocalGroupMembership {
  [Cmdletbinding()]
  PARAM (
    [alias('DnsHostName','__SERVER','Computer','IPAddress')]
    [Parameter(ValueFromPipelineByPropertyName = $true,ValueFromPipeline = $true)]
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [string]$GroupName = "Administrators"
  )
  BEGIN{
  }#BEGIN BLOCK
  PROCESS{
    foreach ($Computer in $ComputerName){
      TRY{
        $Everything_is_OK = $true
        # Testing the connection
        # Write-Verbose -Message "$Computer - Testing connection..."
        # Test-Connection -ComputerName $Computer -Count 1 -ErrorAction Silently |Out-Null
        # Get the members for the group and computer specified
        # Write-Verbose -Message "$Computer - Querying..."
        $Group = [ADSI]"WinNT://$Computer/$GroupName,group"
        $Members = @($Group.psbase.Invoke("Members"))
      }#TRY
      CATCH{
        $Everything_is_OK = $false
        # Write-Warning -Message "Something went wrong on $Computer"
        # Write-Verbose -Message "Error on $Computer"
      }#Catch
      IF($Everything_is_OK){
        # Format the Output
        # Write-Verbose -Message "$Computer - Formatting Data"
        $Members | ForEach-Object -Process {
          $name = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
          $class = $_.GetType().InvokeMember("Class", 'GetProperty', $null, $_, $null)
          $path = $_.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $_, $null)
          # Find out if this is a local or domain object
          if ($path -like "*/$Computer/*"){$Type = "Local"}
          else {$Type = "Domain"}
          $Details = "" | Select-Object -Property ComputerName, Account, Class, Group, Path, Type
          $Details.ComputerName = $Computer
          $Details.Account = $name
          $Details.Class = $class
          $Details.Group = $GroupName
          $Details.Path = $path
          $Details.Type = $Type
          # Show the Output
          $Details
        }
      }#IF(Everything_is_OK)
    }#Foreach
  }#PROCESS BLOCK
  END
  {
    # Write-Verbose -Message "Script Done"
  }#END BLOCK
}

# Setting up the Default Parameters
$Output = (get-location).path + '\ServerInstallationCheck.html'
if ((Test-Path $Output) -like $false)
{New-Item $Output -type file}
$ServerResults = @()

# Importing Active Directory PowerShell Module
Import-Module -Name ActiveDirectory

###################GUI Button#######################################

function button ($title,$serverbx) {

  ###################Load Assembly for creating form & button######

  [void][System.Reflection.Assembly]::LoadWithPartialName( "System.Windows.Forms")
  [void][System.Reflection.Assembly]::LoadWithPartialName( "Microsoft.VisualBasic")

  #####Define the form size & placement

  $form = New-Object "System.Windows.Forms.Form";
  $form.Width = 500;
  $form.Height = 150;
  $form.Text = $title;
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen;

  ##############Define text label1
  $textLabel1 = New-Object "System.Windows.Forms.Label";
  $textLabel1.Left = 25;
  $textLabel1.Top = 15;

  $textLabel1.Text = $serverbx;

  ############Define text box1 for input
  $textBox1 = New-Object "System.Windows.Forms.TextBox";
  $textBox1.Left = 150;
  $textBox1.Top = 10;
  $textBox1.width = 200;

  ############Define text box2 for input

  $textBox2 = New-Object "System.Windows.Forms.TextBox";
  $textBox2.Left = 150;
  $textBox2.Top = 50;
  $textBox2.width = 200;

  ############Define text box3 for input

  $textBox3 = New-Object "System.Windows.Forms.TextBox";
  $textBox3.Left = 150;
  $textBox3.Top = 90;
  $textBox3.width = 200;

  #############Define default values for the input boxes
  $defaultValue = ""
  $textBox1.Text = $defaultValue;

  #############define OK button
  $button = New-Object "System.Windows.Forms.Button";
  $button.Left = 360;
  $button.Top = 85;
  $button.Width = 100;
  $button.Text = "Ok";

  ############# This is when you have to close the form after getting values
  $eventHandler = [System.EventHandler]{
    $textBox1.Text;
  $form.Close();};

  $button.Add_Click($eventHandler) ;

  #############Add controls to all the above objects defined
  $form.Controls.Add($button);
  $form.Controls.Add($textLabel1);

  $form.Controls.Add($textBox1);

  $ret = $form.ShowDialog();

  #################return values

  return $textBox1.Text
}

$return= button "Enter Server Name" "Server Name"

#####################################################################
$Server = $return
$server
Write-Host -Object "Gathering Data for Server Installation Checks..." -ForegroundColor Yellow

# Hardware Information - Domain,Manufacturer,Model,Name,TotalPhysicalMemory
$ServerInfo = Get-WmiObject -Query "Select * from Win32_ComputerSystem" -ComputerName $Server -ErrorAction SilentlyContinue
$RAMinGB = ((($ServerInfo.TotalPhysicalMemory/1024)/1024)/1024)

# Processor Information - Manufacturer,Name,NumberOfCores,NumberOfLogicalProcessors
$CPUInfo = Get-WmiObject -Query "Select * from Win32_Processor" -ComputerName $Server -ErrorAction SilentlyContinue

# Disk Information - DeviceID,VolumeName,Size

$DiskInfo_Size = Get-WmiObject -Class win32_logicaldisk -ComputerName $Server |  Where-Object -FilterScript {$_.drivetype -eq 3}

Write-Host -Object "Collection of Server Hardware Information...Completed!" -ForegroundColor Green

# OS Information - Caption,CSDVersion,OSArchitecture,SystemDrive,Version
$OSDetails = Get-WmiObject -ComputerName $Server -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
Write-Host -Object "Collection of Server OS Information...Completed!" -ForegroundColor Green

# Local Administrators Information - ComputerName,Group,Account,Class,Type
$LocalAdminsData = Get-LocalGroupMembership -ComputerName $Server |
Where-Object -FilterScript {$_.Account -like "*admin*"} |
Select-Object -Property ComputerName, Group, Account, Class, Type
$LocalAdmins = [string]::Join(";",$LocalAdminsData.Account)
Write-Host -Object "Collection of Local Administrators Information...Completed!" -ForegroundColor Green

# Server OU Information - DNSHostname,DistinguishedName
$ServerOU = Get-ADComputer -Identity $Server -Properties * | Select-Object -Property DNSHostname, DistinguishedName,Description

# Security Updates Information - PSComputerName,HotFixID,InstalledOn,InstalledBy
$LatestHotifx = Get-HotFix -ComputerName $Server | Select-Object -Property PSComputerName, HotFixID, InstalledOn, Caption -Last 1
$LatestHotfixID = $LatestHotifx.HotFixID
$LatestHotfixDate = $LatestHotifx.InstalledOn
Write-Host -Object "Collection of Security Updates Information...Completed!" -ForegroundColor Green

# IP address DNS and other properties#####################
$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $Server -EA SilentlyContinue | Where-Object -FilterScript {$_.IPEnabled}

Write-Host -Object "Generating the HTML Export..." -ForegroundColor Green
# generate HTML report###################
Clear-Content $Output
$ServerName = $ServerInfo.DNSHostName
$DomainName = $ServerInfo.Domain
$DomainJoined = $ServerInfo.PartOfDomain
$ServerManufacturer = $ServerInfo.Manufacturer
$ServerModel = $ServerInfo.Model
$PhysicalProcessors = $ServerInfo.NumberOfProcessors
$ProcessorManufacturer = $CPUInfo.Manufacturer
$ProcessorModel = $CPUInfo.Name
$ProcessorCores = $CPUInfo.NumberOfCores
$LogicalProcessors = $CPUInfo.NumberOfLogicalProcessors
$Memory = $RAMinGB
$OSName = $OSDetails.Caption
$OSServicePack	= $OSDetails.CSDVersion
$OSArchitecture = $OSDetails.OSArchitecture
$OSDrive =	$OSDetails.SystemDrive
$OSVersion = $OSDetails.Version
$LocalAdmins
$LatestHotfixID
$LatestHotfixDate
$ServerOUPath = $ServerOU.DistinguishedName
$ServerDescriptioninAD = $ServerOU.Description

#################start generating HTML############################
Add-Content $Output -Value "<h1><strong>Server QA Check List</strong></h1>"
Add-Content $Output -Value "<table style='width: 519px; height: 244px;' border='2'>"
Add-Content $Output -Value "<tbody>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Server Name</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ServerName</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Domain Name</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$DomainName</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Domain Joined</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$DomainJoined</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Server Manufacturer</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ServerManufacturer</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Server Model</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ServerModel</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Physical Processors</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$PhysicalProcessors</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>ProcessorManufacturer</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ProcessorManufacturer</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Processor Model</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ProcessorModel</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Processor Cores</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ProcessorCores</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Logical Processors</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$LogicalProcessors</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Memory (GB)</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$Memory</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'><strong>Drives (in GB)</strong></td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
foreach ($item in $DiskInfo_Size)
{
  $drivelabel = $item.DeviceID
  $drivename = $item.VolumeName
  $drivefreespace = ((($item.FreeSpace/1024)/1024)/1024)
  $driveSize = ((($item.Size/1024)/1024)/1024)
  Write-Host  -Object "fetching drive $drivelabel details" -ForegroundColor green
  Add-Content $Output -Value "<div><br><strong>Drive Label:</strong> $drivelabel</div>"
  Add-Content $Output -Value "<div><strong>Drive Name:</strong> $drivename</div>"
  Add-Content $Output -Value "<div><strong>Drive Free Space:</strong> $drivefreespace</div>"
  Add-Content $Output -Value "<div><strong>Drive Size:</strong> $driveSize<br></div>"
}
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'><strong>OS Name</strong></td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$OSName</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'><strong>OS Service Pack</strong></td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$OSServicePack</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>OS Architecture</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$OSArchitecture</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'><strong>OS Drive</strong></td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$OSDrive</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>OS Version</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$OSVersion</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Local Admins</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$LocalAdmins</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Latest HotfixID</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$LatestHotfixID</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Hotfix Installed On</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$LatestHotfixDate</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Server OU Path</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ServerOUPath</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div><strong>Server Description AD</strong></div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
Add-Content $Output -Value "<div>$ServerDescriptioninAD</div>"
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "<tr>"
Add-Content $Output -Value "<td style='width: 237px;'><strong>Network Information</strong></td>"
Add-Content $Output -Value "<td style='width: 266px;'>"
Add-Content $Output -Value "<div>"
foreach ($Network in $Networks) {
  $IPAddress  = $Network.IpAddress[0]
  $SubnetMask  = $Network.IPSubnet[0]
  $description = $Network.Description
  $DefaultGateway = $Network.DefaultIPGateway
  $DNSServers  = $Network.DNSServerSearchOrder
  $IsDHCPEnabled = $Network.DHCPEnabled
  Write-Host  -Object "fetching drive Network details" -ForegroundColor green
  Add-Content $Output -Value "<div><br><strong>Description:</strong> $description</div>"
  Add-Content $Output -Value "<div><strong>IPAddress:</strong> $IPAddress</div>"
  Add-Content $Output -Value "<div><strong>SubnetMask:</strong>$SubnetMask </div>"
  Add-Content $Output -Value "<div><strong>Default Gateway:</strong> $DefaultGateway</div>"
  Add-Content $Output -Value "<div><strong>DNS Server:</strong> $DNSServers</div>"
  Add-Content $Output -Value "<div><strong>DHCP Enabled:</strong> $IsDHCPEnabled<br></div>"
}
Add-Content $Output -Value "</div>"
Add-Content $Output -Value "</td>"
Add-Content $Output -Value "</tr>"
Add-Content $Output -Value "</tbody>"
Add-Content $Output -Value "</table>"
# Exporting the Formatted Output to HTML
Write-Host -Object "Server Installation Checks Completed on $Server" -ForegroundColor Yellow  
Write-Host -Object "Report Exported to: $Output" -ForegroundColor Yellow

# End of Script