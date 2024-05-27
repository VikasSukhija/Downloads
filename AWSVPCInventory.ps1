<#PSScriptInfo

    .VERSION 1.0

    .GUID 2e9cd356-719e-4484-ab51-c71af2ba4d2f

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
    Created on:   	5/14/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AWSVPCInventory.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This solution will report on VPC inventory

#> 
#################logs and variables##########################
$log = Write-Log -Name "AWSVPCInventory" -folder "logs" -Ext "log"
$Failedlog = Write-Log -Name "Failed" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AWSVPCInventory" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"


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
  Set-DefaultAWSRegion -Region us-east-1
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = (Use-STSRole -RoleArn "arn:aws:iam::123456789:role/Aws-Access-role" -RoleSessionName "assume_role_session").Credentials
  Write-Log -message "Loaded All Modules" -path $log
  Set-AWSCredential -AccessKey $Creds.AccessKeyId -SecretKey $Creds.SecretAccessKey -SessionToken $Creds.SessionToken
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Modules - AWSVPCInventory" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error -AWSVPCInventory" -Body $($_.Exception.Message)
  break;
}
#############################GEt all Accounts################################################
try
{
  Write-Log -message "Fetch all ORg Accounts" -path $log
  $allawsaccounts = Get-ORGAccountList | where{ $_.Status -eq "ACTIVE"}
  Write-Log -message "Fetch all ORg Regions" -path $log
  $regions = Get-EC2Region
  Write-Log -message "Total Accounts and Regions - $($allawsaccounts.count) - $($regions.count)" -path $log

}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Accounts - AWSVPCInventory" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSVPCInventory" -Body $($_.Exception.Message)
  break;
}

#################################get inventory################################################>
$collinventory = @()
foreach($awsAccount in $allawsaccounts)
{
  $error.clear()
  $accoundid = $Accountname = $null
  $accoundid  = $awsAccount.Id
  $Accountname = $awsAccount.Name
  if($accoundid -eq  '987654321'){ #own acocunt
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = Get-AWSCredential
  }
  elseif($accoundid -eq  '123456789'){ #snow account
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
    Write-Log -message "------Error on Account - $accoundid------" -path $Failedlog -Severity Warning
    $error.clear()
  }
  else
  {
    Write-Log -message "Success - $accoundid" -path $log
    foreach($region in $regions)
    {
      $error.clear()
      $VPCsinRegion = $null
      $VPCsinRegion= Get-EC2Vpc -Region $region.Region -Credential $Creds
      if($error)
      {
        $error.clear
        Write-Log -message "$accoundid - $($region.RegionName) VPC not found" -path $log -Severity Warning
      }
      else
      {
        Write-Log -message "$accoundid - $($region.RegionName) VPC found - $($VPCsinRegion.count)" -path $log
        
        if($VPCsinRegion)
        { 
          $VPCsinRegion | ForEach-Object{
            $subnets = $vpc = $tags = $null
            $vpc = $_
            $subnets = Get-EC2Subnet -Region $region.Region -Credential $Creds
            $subnets = $subnets | Where-Object { $_.VpcId -eq $vpc.VpcId }
            Write-Log -message "$accoundid - $($region.RegionName) Subnet found - $($subnets.count)" -path $log
            foreach($subnet in $subnets)
            {
            $tags=$null
            $mcoll = "" | select AccountName,SubnetId,SubnetName,VPCId,State,CIDRBlock,AvailableIPs,OwnerId,ZoneName,Tags
            $tags = ($subnet.Tags  | ConvertTo-csv -NoTypeInformation -Delimiter ":") -join ","
            $mcoll.AccountName = $Accountname
            $mcoll.SubnetId = $subnet.SubnetId
            $mcoll.SubnetName = ($subnet.Tags | where{$_.Key -eq "Name"}).Value
            $mcoll.VPCId = $vpc.VpcId
            $mcoll.State = $subnet.State
            $mcoll.CIDRBlock = $subnet.CidrBlock
            $mcoll.AvailableIPs = $subnet.AvailableIpAddressCount
            $mcoll.OwnerId = $accoundid
            $mcoll.ZoneName = $subnet.AvailabilityZone
            $mcoll.Tags = $tags
            $collinventory += $mcoll
            }
         }
       }
      }
    }
  }
}

$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Report: $($collinventory.count) AWS VPC Inventory" -Attachments $Report
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AWSVPCInventory" -Attachments $log