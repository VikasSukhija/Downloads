<#PSScriptInfo

    .VERSION 1.1

    .GUID cb0bb5f9-c1b1-467e-a297-5e498944a5e4

    .AUTHOR Vikas Sukhija

    .COMPANYNAME TechWizard.cloud

    .COPYRIGHT Vikas Sukhija

    .TAGS

    .LICENSEURI https://techwizard.cloud/

    .PROJECTURI https://techwizard.cloud/

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES 

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES https://techwizard.cloud/


    .PRIVATEDATA
    ===========================================================================
    Created with: 	ISE
    Created on:   	4/18/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AWSOlderSnapShots.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This solution will extract rport on older snapshots

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "AWSOlderSnapShots" -folder "logs" -Ext "log"
$Failedaccountslog = Write-Log -Name "FailedAccounts" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AWSOlderSnapShots" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"
$3monthsAgo = (Get-Date).AddDays(-90)

$email1 =  "Vikas@labtest.com"
##################Admin params##########################
$smtpserver = "smtpserver"
$erroremail = "reports@labtest.com"
$from = "DoNotRespond@labtest.com"
######################Spo Cet Auth#########################
$AccessKey = "Access Key"
$SecretKey = "Secret Key"
#########################################################################
try
{
  Write-Log -message "Start ......... Script" -path $log
  Import-Module AWSPowershell
  Set-DefaultAWSRegion -Region us-east-1
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = (Use-STSRole -RoleArn "arn:aws:iam::123456789:role/Aws-Access-role" -RoleSessionName "assume_role_session").Credentials
  Write-Log -message "Loaded All Modules" -path $log
  Set-AWSCredential -AccessKey $Creds.AccessKeyId -SecretKey $Creds.SecretAccessKey -SessionToken $Creds.SessionToken
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading modules - AWSOlderSnapShots" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSOlderSnapShots" -Body $($_.Exception.Message)
  break;
}
#############################GEt all Accounts################################################
try
{
  Write-Log -message "Fetch all ORg Accounts" -path $log
  $allawsaccounts = Get-ORGAccountList | where{ $_.Status -eq "ACTIVE"}
  Write-Log -message "Fetch all ORg Regions" -path $log
  $regions = Get-EC2Region
  Write-Log -message "Total Accounts - $($allawsaccounts.count)" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Accounts - AWSOlderSnapShots" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSOlderSnapShots" -Body $($_.Exception.Message)
  break;
}

#################################get inventory################################################>
$collinventory = New-Object System.Collections.ArrayList
foreach($awsAccount in $allawsaccounts)
{
  $error.clear()
  $accoundid = $Accountname = $null
  $accoundid  = $awsAccount.Id
  $Accountname = $awsAccount.Name
  if($accoundid -eq  '987654321'){
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = Get-AWSCredential
  }
  elseif($accoundid -eq  '123456789'){
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = (Use-STSRole -RoleArn "arn:aws:iam::123456789:role/Aws-Access-role" -RoleSessionName "assume_role_session").Credentials
  }
  else{
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = (Use-STSRole -RoleArn "arn:aws:iam::123456789:role/Aws-Access-role" -RoleSessionName "assume_role_session").Credentials
  Set-AWSCredential -AccessKey $Creds.AccessKeyId -SecretKey $Creds.SecretAccessKey -SessionToken $Creds.SessionToken
  $Creds = (Use-STSRole -RoleArn $("arn:aws:iam::$accoundid" + ":role/Aws-Access-role") -RoleSessionName "assume_role_session_1").Credentials
  }
  if($error)
  {
    Write-Log -message "------Error on Account - $accoundid------" -path $Failedaccountslog -Severity Warning
    $error.clear()
  }
  else
  {
    Write-Log -message "Success - $accoundid" -path $log
    foreach($region in $regions)
    {
      $error.clear()
      $SnapshotsinRegion = $null
      $filter = New-Object Amazon.EC2.Model.Filter
      $filter.Name = 'tag-key'
      $filter.Value.Add('Name')
      $SnapshotsinRegion =  Get-EC2Snapshot -Region $region.RegionName -Credential $Creds -OwnerId $accoundid -ErrorAction SilentlyContinue
      $SnapshotsinRegion = $SnapshotsinRegion.where{$_.StartTime -lt $3monthsAgo}
      if($error)
      {
        $error.clear
        Write-Log -message "$accoundid - $($region.RegionName) Inventory not found" -path $log -Severity Warning
      }
      else
      {

        Write-Log -message "$accoundid - $($region.RegionName) Inventory found - $($SnapshotsinRegion.count)" -path $log

        if($SnapshotsinRegion)
        { 
        ForEach($i in $SnapshotsinRegion) {
          $tags = $SnapshotName= $null
          $tags = $i.Tags

          if(!([string]::IsNullOrEmpty($tags)))
          {
            if($tags.Key -eq "Name")
            {
              $SnapshotName = $tags |
              Where-Object -FilterScript {
                $_.Key -eq "Name" 
              } |
              Select-Object -ExpandProperty Value
            }
          }
            $mcoll = "" | select AccountName,SnapshotName,SnapshotId,VolumeName,Size,RegionName,CreateDate,SnapshotAge
            $mcoll.AccountName = $Accountname
            if($SnapshotName){$mcoll.SnapshotName = $SnapshotName}
            else{$mcoll.SnapshotName = $i.SnapshotId}
            $mcoll.SnapshotId = $i.SnapshotId
            $mcoll.VolumeName = $i.VolumeId
            $mcoll.Size = $i.VolumeSize
            $mcoll.RegionName = $($region.RegionName)
            $mcoll.CreateDate= $i.StartTime
            $mcoll.SnapshotAge= $i.StartTime
            $collinventory.add($mcoll)

          }
        }
      }
    }
  }
}

$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Critical Alert: $($collinventory.count) Amazon Snapshots are older than 3 months" -Attachments $Report
Move-Item -Path $report -Destination $hitoricalreports -Force
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AWSOlderSnapShots" -Attachments $log
