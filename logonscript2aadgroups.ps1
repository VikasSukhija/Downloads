<#	
    .NOTES
    ===========================================================================
    Created with: 	ISE
    Created on:   	6/7/2024 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	logonscript2aadgroups.ps1
    ===========================================================================
    .DESCRIPTION
    This will created and update ad groupmembership based on logons cripts
#>
#################logs and variables##########################
$log = Write-Log -Name "logonscript2aadgroups" -folder "logs" -Ext "log"

$logrecyclelimit = "60"
$countofchanges ="50"
$regex = "^[a-zA-Z0-9_-]*\.bat$"
$prefix = "labtest-LogonScript"  #Logon script groups prefix
$prefixwildcard = "labtest-LogonScript_*" #Logon script groups prefix wildcard
$GroupOU = "OU=TEST,OU=Groups,DC=labtest,DC=com"
$templateuser = "TestUser1"
###################Admin params##########################
$smtpserver = "SMTPServer"
$erroremail = "logsandalerts@labtest.com"
$from = "DNR@labtest.com"
########################################################################
try
  {
    Write-Log -Message "Start ......... Script" -path $log
    $getalllogonscriptusers = Get-ADUser -Filter {scriptPath -like "*" -and Enabled -eq $true} -Properties scriptPath | Select scriptPath,samaccountname
    Write-Log -message "Total users account found with logon script - $($getalllogonscriptusers.count)" -Path $log
    $getalllogonscripts = $getalllogonscriptusers | group-object scriptPath -AsHashTable
    Write-Log -message "Total logon scripts  - $($getalllogonscripts.count)" -Path $log
  }
  catch
  {
    $exception = $_.Exception.Message
    Write-Log -Message "exception $exception has occured loading CSOM - logonscript2aadgroups" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "CSOM Error - logonscript2aadgroups" -Body $($_.Exception.Message)
    break;
  }

#######Start creating AD groups with naming logon script prefix with no extension if does not exists##############
$errcolllogonscripts=@()
foreach ($logonscript in $getalllogonscripts.keys)
{
    $logonscriptname = $groupname = $adgroup =  $null
    $logonscript=[string]$logonscript.ToLower()
    #######exclude the logon scipts that are not in format abcd.bat##############
  if($logonscript -match $regex){
    $logonscriptname = $logonscript -replace ".bat",""
    $logonscriptname =$logonscriptname.trim()
    $groupname = $prefix + "_" + $logonscriptname
    Write-Log -Message "Process - $logonscriptname - $groupname" -path $log
    $adgroup = Get-ADGroup -identity $groupname -ErrorAction SilentlyContinue
    $error.clear()
    if($adgroup){
        Write-Log -Message "Group $groupname already exists" -path $log
    }
    else
    {
        try
        {
            Write-Log -Message "Creating group $groupname" -path $log
            New-ADGroup -Name $groupname -DisplayName $groupname -Path $GroupOU -GroupScope Universal -GroupCategory Security -Description "Group for logon script $logonscriptname"
            Write-Log -Message "Group $groupname created" -path $log
            $getadgroup = Get-ADGroup -identity $groupname -erroraction SilentlyContinue
            while ($getadgroup -eq $null) {
              Start-Sleep -Seconds 5
              $getadgroup = Get-ADGroup -identity $groupname -erroraction SilentlyContinue
            }
            $error.clear()
            ADD-ADGroupMember -identity $groupname -Members $templateuser -Confirm:$false
        }
        catch
        {
            $exception = $_.Exception.Message
            Write-Log -Message "exception $exception has occured creating group $groupname - logonscript2aadgroups" -path $log -Severity Error
            Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error creating group $groupname - logonscript2aadgroups" -Body $($_.Exception.Message)
            break;
        }
    }
  }
  else{
    Write-Log -Message "Logon script $logonscript does not match the regex" -path $log
    $errcolllogonscripts+= $logonscript
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error Logon script $logonscript does not match the Format" -Body "Logon script $logonscript does not match the Format"
  }
}
####################ADD users to groups############################################
foreach ($logonscript in $getalllogonscripts.keys)
{
    $logonscriptname = $groupname = $adgroup = $getusers = $getgroupmembership = $changes = $null
    $logonscript=[string]$logonscript.ToLower()
    if($logonscript -match $regex){
    $logonscriptname = $logonscript -replace ".bat",""
    $logonscriptname =$logonscriptname.trim()
    $groupname = $prefix + "_" + $logonscriptname
    Write-Log -Message "Process groupmembership - $logonscriptname - $groupname" -path $log
    $adgroup = Get-ADGroup -identity $groupname -ErrorAction SilentlyContinue
    $error.clear()
    if($adgroup){
        Write-Log -Message "Group $groupname exists" -path $log
        $getusers = $getalllogonscripts[$logonscript]
        $getgroupmembership = Get-ADGroupMembersRecursive -Groups $groupname
        $changes = Compare-Object -ReferenceObject $getusers -DifferenceObject $getgroupmembership  -Property samaccountname | Select-Object -Property samaccountname, @{
          n = 'State'
          e = {If ($_.SideIndicator -eq "=>"){"Removal" } Else { "Addition" }}
          }
          if($Changes){
            $removal = $Changes | Where-Object -FilterScript {$_.State -eq "Removal"} | Select -ExpandProperty samaccountname
            $Addition = $Changes | Where-Object -FilterScript {$_.State -eq "Addition"} | Select -ExpandProperty samaccountname
            if($Addition){
              $addcount = $Addition.count
              Write-Log -Message "Adding members to $ADgroup count $addcount" -path $log
              if($addcount -le $countofchanges){
                $Addition | ForEach-Object{
                  $amem = $_
                  Write-Log -Message "ADD  $amem  to $ADgroup" -path $log
                  ADD-ADGroupMember -identity $ADgroup -Members $amem -Confirm:$false
                }
              }else{
                Write-Log -Message "ADD count $addcount is more than $countofchanges - $ADgroup" -path $log -Severity Error
                Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured ADD count $addcount is more than $countofchanges - logonscript2aadgroups" -Body "Error has occured ADD count $addcount is more than $countofchanges - logonscript2aadgroups - $ADgroup"
              }
              }
            if($removal){
                $remcount = $removal.count
                Write-Log -Message "Removing members from $ADgroup count $remcount" -path $log
                if($remcount -le $countofchanges){
                  $removal | ForEach-Object{
                    $rmem = $_
                    Write-Log -Message "Remove $rmem from $ADgroup" -path $log
                    Remove-ADGroupMember -identity $ADgroup -Members $rmem -Confirm:$false
                  }     
                }else{
                  Write-Log -Message "Remove count $remcount is more than $countofchanges - $ADgroup" -path $log -Severity Error
                  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error has occured Remove count $remcount is more than $countofchanges - logonscript2aadgroups" -Body "Error has occured Remove count $remcount is more than $countofchanges - logonscript2aadgroups - $ADgroup"   
                } 
              }
           }  
    }
    else
    {
        Write-Log -Message "Group $groupname does not exists" -path $log
    }

  }
}
################################Find groups with no logon script#####################
$allgroups = Get-ADGroup -Filter {Name -like $prefixwildcard} -SearchBase $GroupOU
Write-Log -Message "Collected Logon Script Groups from AD $($allgroups.count)" -path $log
$collectlogonscriptgroups = @()
foreach ($logonscript in $getalllogonscripts.keys){
    $logonscriptname = $groupname = $adgroup = $null
    $logonscript=[string]$logonscript.ToLower()
    if($logonscript -match $regex){
    $logonscriptname = $logonscript -replace ".bat",""
    $logonscriptname =$logonscriptname.trim()
    $groupname = $prefix + "_" + $logonscriptname
    $collectlogonscriptgroups += $groupname
    }
}

$collalladgroups = $allgroups.Name | Sort-Object
$collectlogonscriptgroups = $collectlogonscriptgroups | Sort-Object
Write-Log -Message "Collected Logon Script Groups from Naming Convention $($collectlogonscriptgroups.count)" -path $log
$findgroups = Compare-Object -ReferenceObject $collectlogonscriptgroups -DifferenceObject $collalladgroups
$findgroups = $findgroups | Where-Object -FilterScript {$_.SideIndicator -eq "=>"} | Select -ExpandProperty InputObject
if($findgroups){
  Write-Log -Message "Groups with no logon script $($findgroups.count)" -path $log
  $groups = $findgroups -join "`n"
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Groups with no logon script $($findgroups.count)" -Body $groups
}
#########################Recycle Logs#################################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - logonscript2aadgroups" -Attachments $log
#######################################################################################