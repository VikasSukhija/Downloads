<#PSScriptInfo

    .VERSION 1.0

    .GUID ee0b85af-6a71-4ebd-ad3c-908c3a11ca36

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
    Filename:     	AWSEC2Iventory.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This solution will fetch AWS EC2 inventory Report

#> 
param()
#################logs and variables#####################
$log = Write-Log -Name "AWSEC2Iventory" -folder "logs" -Ext "log"
$Failedlog = Write-Log -Name "Failed" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AWSEC2Inventory" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"
$email1 = "Vikas@labtest.com"
###################Admin params##########################
$smtpserver = "smtpserver"
$erroremail = "reports@labtest.com"
$from = "DoNotRespond@labtest.com"
######################Spo Cet Auth#########################
$AccessKey = "Access Key"
$SecretKey = "Secret Key"
#########################################################################
try
{
  import-module AWSPowershell
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
  Write-Log -message "exception $exception has occured loading  - AWSEC2Iventory" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSEC2Iventory" -Body $($_.Exception.Message)
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
  Write-Log -message "exception $exception has occured loading - AWSEC2Iventory" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSEC2Iventory" -Body $($_.Exception.Message)
  break;
}

#################################get inventory################################################>
$collinventory = New-Object System.Collections.ArrayList
foreach($awsAccount in $allawsaccounts)
{
  $error.clear()
  $accoundid = $Accountname =$null
  $accoundid  = $awsAccount.Id
  $Accountname = $awsAccount.Name
  if($accoundid -eq  '987654321'){ #############main account
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = Get-AWSCredential
  }
  elseif($accoundid -eq  '123456789'){##############servicenow account
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
      $getallec2inregion = $null
      $getallec2inregion = Get-EC2Instance -Region $region.RegionName -Credential $Creds -ErrorAction SilentlyContinue
      if($error)
      {
        $error.clear
        Write-Log -message "$accoundid - $($region.RegionName) Inventory not found" -path $log -Severity Warning
      }
      else
      {
        Write-Log -message "$accoundid - $($region.RegionName) Inventory found - $($getallec2inregion.count)" -path $log

        if($getallec2inregion)
        { 
        $getallec2inregion.Instances | ForEach-Object{
          $mcoll = "" | select AccountName, OwnerId, InstanceId, InstanceName,ZoneName ,tag, APIName, VirtualCores, Memory, Disk, AttachedEBS, PrivateIP,PublicIP,VpcId, Product, AMI,State,Tags, LaunchDate, ListPricePerMonth, ProjectedCostForMonth, TotalCostMTD, FirstDiscovered
            
            $tags = $InstanceName  = $memoryinmb = $volsize = $Ebsvol = $instnaceid = $null
            
            $tags = $_.Tags

            if(!([string]::IsNullOrEmpty($tags)))
            {
              if($tags.Key -eq "Name")
              {
                $InstanceName = $tags |
                Where-Object -FilterScript {
                  $_.Key -eq "Name" 
                } |
                Select-Object -ExpandProperty Value
              }
            }
            
            $Ebsvol = $_.BlockDeviceMappings.ebs.VolumeId
            $instnaceid = $_.instanceId

            if($_.InstanceType )
            {
              $memoryinmb = $(Get-EC2InstanceType -InstanceType $_.InstanceType -Credential $Creds | select MemoryInfo -ExpandProperty MemoryInfo).SizeInMiB
              if($error)
              {
                Write-Log -message "error - $($error) - $accoundid - $($_.InstanceType) - $instnaceid - $($region.RegionName)" -path $log -Severity Warning
                $error.clear()
              }
              
            }
   

            if($Ebsvol)
            { 
              $Ebsvol | ForEach-Object {
                $volsize += $(Get-EC2Volume -VolumeId $_ -Credential $Creds -Region $($region.RegionName) -ErrorAction SilentlyContinue).Size
                if($error)
                {
                  Write-Log -message "error - $($error) $accoundid -  $($_) -  $instnaceid - $($region.RegionName)" -path $log -Severity Warning
                  $error.clear()
                }
              }

            }

            ############################################################################
            $mcoll.AccountName = $Accountname
            $mcoll.Ownerid = $accoundid
            $mcoll.instanceId = $_.instanceId
            $mcoll.InstanceName = $InstanceName
            $mcoll.ZoneName = $_.Placement.AvailabilityZone
            $mcoll.tag =  ($tags | ConvertTo-csv -NoTypeInformation -Delimiter ":") -join ","
            $mcoll.APIName = $_.InstanceType
            $mcoll.VirtualCores = $_.CpuOptions.CoreCount
            $mcoll.Memory = $memoryinmb
            $mcoll.Disk = $volsize
            $mcoll.AttachedEBS = $volsize 
            $mcoll.PrivateIP = $_.PrivateIpAddress
            $mcoll.PublicIP = $_.PublicIpAddress
            $mcoll.VpcId = $_.VpcId
            $mcoll.product = $_.PlatformDetails
            $mcoll.AMI = $_.ImageId
            $mcoll.State = $_.State.Name
            $mcoll.tags =  ($tags | ConvertTo-csv -NoTypeInformation -Delimiter ":") -join ","
            $mcoll.launchdate = $_.LaunchTime
            $mcoll.ListPricePerMonth = ""
            $mcoll.ProjectedCostForMonth = ""
            $mcoll.TotalCostMTD = ""
            $mcoll.FirstDiscovered = $_.LaunchTime
            $collinventory.add($mcoll)
          }
        }
      }
    }
  }
}

$collinventory | Export-Csv $Report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "AWS EC2 Instance Inventory Report" -Attachments $Report
Move-Item -Path $report -Destination $hitoricalreports -Force
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Set-Recyclelogs -foldername "Report" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AWSEC2Iventory" -Attachments $log