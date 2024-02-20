<#PSScriptInfo

    .VERSION 1.0

    .GUID 6e0be15b-89a4-43f7-a485-66ad7f42a95a

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
    Created on:   	8/11/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AWSDataBaseReport.ps1
    https://instances.vantage.sh/rds/ (for pricing)
    ===========================================================================

#>
<# 

    .DESCRIPTION 
    This solution will generate AWS Database Report

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "AWSDataBaseReport" -folder "logs" -Ext "log"
$Failedlog = Write-Log -Name "Failed-AWSDataBaseReport" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AWSDataBaseReport" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"
$AmazonRDSInstanceComparison = (get-location).path + "\Amazon RDS Instance Comparison.csv"

$email1 =  "Vikas@labtest.com"
##################Admin params##########################
$smtpserver = "smtpserver"
$erroremail = "reports@labtest.com"
$from = "DoNotRespond@labtest.com"
######################Spo Cet Auth######################
$AccessKey = "Access Key"
$SecretKey = "Secret Key"
########################################################
try
{
  Import-Module AWSPowerShell
  Write-Log -message "Start ......... Script" -path $log
  $AWSRDSconfigdata = Import-Csv $AmazonRDSInstanceComparison
  Set-DefaultAWSRegion -Region us-east-1
  Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey
  $Creds = (Use-STSRole -RoleArn "arn:aws:iam::123456789:role/Aws-Access-role" -RoleSessionName "assume_role_session").Credentials
  Write-Log -message "Loaded All Modules" -path $log
  Set-AWSCredential -AccessKey $Creds.AccessKeyId -SecretKey $Creds.SecretAccessKey -SessionToken $Creds.SessionToken
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Modules - AWSDataBaseReport" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSDataBaseReport" -Body $($_.Exception.Message)
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
  Write-Log -message "exception $exception has occured loading Accounts - AWSDataBaseReport" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSDataBaseReport" -Body $($_.Exception.Message)
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
    Write-Log -message "------Error on Account - $accoundid------" -path $Failedlog -Severity Warning
    $error.clear()
  }
  else
  {
    Write-Log -message "Success - $accoundid" -path $log
    foreach($region in $regions)
    {
      $error.clear()
      $RDSDBInstanceinRegion = $null
      $RDSDBInstanceinRegion = Get-RDSDBInstance -Region $region.RegionName -Credential $Creds -ErrorAction SilentlyContinue
      if($error)
      {
        $error.clear
        Write-Log -message "$accoundid - $($region.RegionName) Inventory not found" -path $log -Severity Warning
      }
      else
      {
        Write-Log -message "$accoundid - $($region.RegionName) Inventory found - $($VolumesinRegion.count)" -path $log
        
        if($RDSDBInstanceinRegion)
        { 
        $RDSDBInstanceinRegion | ForEach-Object{
        $costcenter =  $tags = $Application = $environment = $Owner = $APIName = $null
        $tags = $_.TagList
        if(!([string]::IsNullOrEmpty($tags)))
        {
          if($tags.Key -eq "costcenter")
          {
            $costcenter = $tags |
            Where-Object -FilterScript {
              $_.Key -eq "costcenter" 
            } |
            Select-Object -ExpandProperty Value
          }
        }

        if(!([string]::IsNullOrEmpty($tags)))
        {
          if($tags.Key -eq "environment")
          {
            $environment = $tags |
            Where-Object -FilterScript {
              $_.Key -eq "environment" 
            } |
            Select-Object -ExpandProperty Value
          }
        }

        if(!([string]::IsNullOrEmpty($tags)))
        {
          if($tags.Key -eq "Application")
          {
            $Application = $tags |
            Where-Object -FilterScript {
              $_.Key -eq "Application" 
            } |
            Select-Object -ExpandProperty Value
          }
        }

        if(!([string]::IsNullOrEmpty($tags)))
        {
          if($tags.Key -eq "owner")
          {
            $owner = $tags |
            Where-Object -FilterScript {
              $_.Key -eq "owner" 
            } |
            Select-Object -ExpandProperty Value
          }
        }

        $APIName = $_.DBInstanceClass
        $mcoll = "" | select AccountName,InstanceId,ZoneName,MultiAZ,Snapshots,Encrypted,CreatedOn,DBName,Engine,Version,Username,costcenter,Size,Pillars,Tags,FullName,APIName,Memory,VirtualCores,Status,Endpoint,LatestBackup,MaintenanceWindow,BackupRetention,Active,Accounts,Application,Environment,Owner,OwnerId,VPCID
        
        $mcoll.AccountName = $Accountname
        $mcoll.InstanceId = $_.DBInstanceIdentifier
        $mcoll.ZoneName = $_.AvailabilityZone
        $mcoll.MultiAZ = $_.MultiAZ
        $mcoll.Snapshots = $_.CopyTagsToSnapshot
        $mcoll.Encrypted = $_.StorageEncrypted
        $mcoll.CreatedOn = $_.InstanceCreateTime
        $mcoll.DBName = $_.DBName
        $mcoll.Engine = $_.Engine
        $mcoll.Version = $_.EngineVersion
        $mcoll.Username = $_.MasterUsername
        $mcoll.costcenter = $costcenter
        $mcoll.Size = $_.AllocatedStorage
        $mcoll.Pillars = $null
        $mcoll.Tags = ($tags | ConvertTo-csv -NoTypeInformation -Delimiter ":") -join ","
        $mcoll.FullName = $($AWSRDSconfigdata  | where{$_."API Name" -eq $APIName}).Name
        $mcoll.APIName = $APIName
        $mcoll.Memory =  $($AWSRDSconfigdata  | where{$_."API Name" -eq $APIName}).Memory
        $mcoll.VirtualCores =  $($AWSRDSconfigdata  | where{$_."API Name" -eq $APIName}).vCPUs
        $mcoll.Status = $_.DBInstanceStatus
        $mcoll.Endpoint = $_.Endpoint.Address
        $mcoll.LatestBackup = $_.LatestRestorableTime
        $mcoll.MaintenanceWindow = $_.PreferredMaintenanceWindow
        $mcoll.BackupRetention = $_.BackupRetentionPeriod
        if($_.DBInstanceStatus -eq 'available')
        {
            $mcoll.Active = 'True'
        }
        else
        {
            $mcoll.Active = 'False'
        }
        $mcoll.Accounts = $Accountname
        $mcoll.Application = $Application
        $mcoll.Environment = $environment
        $mcoll.Owner = $Owner
        $mcoll.OwnerId = $accoundid
        $mcoll.VPCID = $_.DBSubnetGroup.VpcId
        $collinventory += $mcoll

          }
        }
      }
    }
  }
}

$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "AWS Database Report" -Attachments $Report
Move-Item -Path $report -Destination $hitoricalreports -Force
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AWSDataBaseReport" -Attachments $log