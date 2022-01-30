# ################################################################################################################################
# Author: Doug Blanchard
# Description: This report pulls hourly email flow information from Hub Transport server logs
# Security: You may need to run [ Set-ExecutionPolicy Unrestricted ] prior to running this script
# Usage: no arguments needed
# Prerequisites: See PreRequisites section at bottom of script
# Modified - Vikas Sukhija --> Chart the per hourly rates of email flow & modified the email function to work with Powershell 1.0
# ################################################################################################################################


$error.clear()
$warningpreference = "silentlycontinue"


# ########################################
# List all Functions to be Used in Script
# ########################################


# ~~~~~~~~~~~~~~~~~~~~~~~~
# Hub Transport Stats Function
# ~~~~~~~~~~~~~~~~~~~~~~~~
  # Pulls # of messages sent, received, and NDR per hub transport server
  # Based on data pulled from http://gsexdev.blogspot.com/2010/05/quck-smtp-bandwidth-usage-script-for.html
 Function HubStatsFunc($tlength1,$tlength2)
 {
   $date = ((get-date).AddHours(-24).ToString('yyyy/MM/dd'))
   write-host $tlength1 $tlength2
   $start = $date+  $tlength1
   $end = $date+  $tlength2
   
   $HubSrv = @()
   $DomainHash = @{}
   $msgIDArray = @{}

   get-accepteddomain | ForEach-Object {
        if ($_.DomainType -eq "Authoritative")
        {$DomainHash.add($_.DomainName.SmtpDomain.ToString().ToLower(),1)}
        }

   $hub = Get-TransportServer | Select Name
   foreach ($item in $hub)
     {

$InternalNum = 0
$ExternalSentNum =0
$ExternalRecNum =0
$InternalSize =0
$ExternalSentSize =0
$ExternalRecSize =0
$DSNCount = 0

      Get-MessageTrackingLog -server $item.Name -ResultSize Unlimited -Start $start -End $end | ForEach-Object{
          if ($_.EventID.ToString() -eq "SEND" -bor $_.EventID.ToString() -eq "RECEIVE")
           {foreach($recp in $_.recipients)
             {if($recp.ToString() -ne "")
               {$unkey = $recp.ToString() + $_.Sender.ToString() + $_.MessageId.ToString()
                  if ($msgIDArray.ContainsKey($unkey) -eq $false){
                     $msgIDArray.Add($unkey,1)
                     $recparray = $recp.split("@")
                     $sndArray = $_.Sender.split("@")
                     if ($_.Sender -ne ""){
                      if ($DomainHash.ContainsKey($recparray[1])){
                          if ($DomainHash.ContainsKey($sndArray[1])){
                          $InternalNum = $InternalNum + 1
                          $InternalSize = $InternalSize + $_.TotalBytes/1024
                         }
                       else{
                          $ExternalRecNum = $ExternalRecNum + 1 
                          $ExternalRecSize = $ExternalRecSize + $_.TotalBytes/1024
                         } 
                       }
                     else{
                       if ($DomainHash.ContainsKey($sndArray[1])){
                       $ExternalSentNum = $ExternalSentNum + 1 
                       $ExternalSentSize = $ExternalSentSize + $_.TotalBytes/1024
                      } 
                   }
                 }
               }
             }
           } 
         }
       }
       $GetDSN = Get-MessageTrackingLog -server $item.Name -EventID DSN -resultSize unlimited | Measure-Object
       $DSNCount = $GetDSN.count
       $obj = New-Object PSObject
       $Obj | Add-Member NoteProperty -Name "Server" -Value $item.Name
       $Obj | Add-Member NoteProperty -Name "# Msg Sent/Rcvd<br>  Internal" -Value $InternalNum
       $Obj | Add-Member NoteProperty -Name "# Msg Sent<br>  Internet" -Value $ExternalSentNum
       $Obj | Add-Member NoteProperty -Name "# Msg Rcvd<br>  Internet" -Value $ExternalRecNum
       $Obj | Add-Member NoteProperty -Name "Msg Sent/Rcvd (MB)<br>  Internal" -Value ([math]::round($InternalSize/1024,0))
       $Obj | Add-Member NoteProperty -Name "Msg Sent (MB)<br>  Internet" -Value ([math]::round($ExternalSentSize/1024,0))
       $Obj | Add-Member NoteProperty -Name "Msg Rcvd (MB)<br>  Internet" -Value ([math]::round($ExternalRecSize/1024,0))
       $Obj | Add-Member NoteProperty -Name "Total #<br>of DSN" -Value $DSNCount
       $HubSrv += $Obj
     }
    $HubSrv | ConvertTo-Html | Out-File C:\Temp\hub.tmp
 }

# End Hub Transport Stats Function
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



# ~~~~~~~~~~~~~~~~~~~~~~~~
# Send Email Function
# ~~~~~~~~~~~~~~~~~~~~~~~~
  # Sends the output file to the administrator

  
$message = new-object System.Net.Mail.MailMessage(“Script@abcdef.com“, “mahesh.sharma@abcdef.com“)
$message.IsBodyHtml = $True
$message.Subject = "Daily Messaging Status Report - " +$(Get-Date -Uformat %D)
$smtp = new-object Net.Mail.SmtpClient("smtpservername")

   

# End Send Email Function
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~


# #############################
# Powershell Script Starts Here
# #############################

# Create Directory, Tmp, & Output File
#   $dirname = "C:\Temp\$(Get-Date -format 'yyyyMMdd')"
#   New-Item $dirname -itemType directory | out-null

    $OutputF = "C:\Temp\DailyReport_$(Get-Date -format 'yyyyMMdd').html"
    New-Item $OutputF -itemType file | out-null

    $Tmp = "C:\temp\$(Get-Date -format 'yyyyMMdd').tmp"
      If(test-path $Tmp -pathtype leaf){remove-item -path $Tmp -force}
      ELSE {New-Item $Tmp -itemType file | out-null}


# Create Array for HTML Output
   $output = @()
   $output += '<html><head><title>Daily Status Report</title></head><body>'
   $output += '<style>table{border-style:solid;border-width:1px;font-size:8pt;background-color:#ccc;width:100%;}th{text-align:left;}td{background-color:#fff;border-style:solid;border-width:1px;}body{font-family:verdana;font-size:8pt;}h1{font-size:12pt;}h2{font-size:10pt;}</style>'
   $output += Get-Date


# Call Hub Stats Function1
   write-host "Gathering Message stats..."
   $output += '<h1>Message Stats</h1>'
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 00:00 to 01:00 '
   $tlength1 = " 00:00:00"
   $tlength2 = " 01:00:00"

   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function2
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 01:00 to 02:00 '
   $tlength1 = " 01:00:01"
   $tlength2 = " 02:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function3
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 02:00 to 03:00 '
   $tlength1 = " 02:00:01"
   $tlength2 = " 03:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function4
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 03:00 to 04:00 '
   $tlength1 = " 03:00:01"
   $tlength2 = " 04:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function5
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 04:00 to 05:00 '
   $tlength1 = " 04:00:01"
   $tlength2 = " 05:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"
# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 05:00 to 06:00 '
   $tlength1 = " 05:00:01"
   $tlength2 = " 06:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 06:00 to 07:00 '
   $tlength1 = " 06:00:01"
   $tlength2 = " 07:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"


# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 07:00 to 08:00 '
   $tlength1 = " 07:00:01"
   $tlength2 = " 08:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"


# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 08:00 to 09:00 '
   $tlength1 = " 08:00:01"
   $tlength2 = " 09:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"


# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 09:00 to 10:00 '
   $tlength1 = " 09:00:01"
   $tlength2 = " 10:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"


# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 10:00 to 11:00 '
   $tlength1 = " 10:00:01"
   $tlength2 = " 11:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"


# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 11:00 to 12:00 '
   $tlength1 = " 11:00:01"
   $tlength2 = " 12:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 12:00 to 13:00 '
   $tlength1 = " 12:00:01"
   $tlength2 = " 13:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 13:00 to 14:00 '
   $tlength1 = " 13:00:01"
   $tlength2 = " 14:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 14:00 to 15:00 '
   $tlength1 = " 14:00:01"
   $tlength2 = " 15:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 15:00 to 16:00 '
   $tlength1 = " 15:00:01"
   $tlength2 = " 16:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 16:00 to 17:00 '
   $tlength1 = " 16:00:01"
   $tlength2 = " 17:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 17:00 to 18:00 '
   $tlength1 = " 17:00:01"
   $tlength2 = " 18:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 18:00 to 19:00 '
   $tlength1 = " 18:00:01"
   $tlength2 = " 19:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 19:00 to 20:00 '
   $tlength1 = " 19:00:01"
   $tlength2 = " 20:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 20:00 to 21:00 '
   $tlength1 = " 20:00:01"
   $tlength2 = " 21:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 21:00 to 22:00 '
   $tlength1 = " 21:00:01"
   $tlength2 = " 22:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 22:00 to 23:00 '
   $tlength1 = " 22:00:01"
   $tlength2 = " 23:00:00"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"

# Call Hub Stats Function6
   write-host "Gathering Message stats..."
   $output += 'Messages sent and received thru Hub Transport servers yesterday between 23:00 to 23:59 '
   $tlength1 = " 23:00:01"
   $tlength2 = " 23:59:59"
   HubStatsFunc $tlength1 $tlength2
   $output += get-content C:\Temp\hub.tmp
   $output += "<p><hr></p>"



# Finish and call output file
   $output += '</body></html>'	
   $output | Out-File $OutputF -Force
#   ii $OutputF

# Send email to Exchange Team
  write-host "Sending the email..."
  $body = get-content $outputF | ForEach-Object {$fullstring = ""} {$fullstring += $_} {$fullstring} 
  $message.Body = $body
  $smtp.Send($message)


# Clean Up
  get-childitem c:\temp -include *.tmp -recurse | foreach ($_) {remove-item $_.fullname}



# #############################################################################
# PREREQUISITES FOR SCRIPT!!!!
#   1. Line 102: Update the Email Address information 
#   2. Line 105: Update the SMTP server that you want to relay this message through
#   3. C:\Temp drive is used to store tmp files.  If this is not sufficient, do find/replace for C:\temp
#   4. Copy the script in c:\temp location to run it without any errors.



