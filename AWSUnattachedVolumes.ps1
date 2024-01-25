<#PSScriptInfo

    .VERSION 1.1

    .GUID e0b9ece3-1a85-43bd-96de-2c2610083d81

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
    Filename:     	AWSUnattachedVolumes.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This solution will extract report on AWSUnattachedVolumes

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "AWSUnattachedVolumes" -folder "logs" -Ext "log"
$Failedlog = Write-Log -Name "Failed" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AWSUnattachedVolumes" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"

$oneWeekAgo = (Get-Date).AddDays(-7)

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
  Write-Log -message "exception $exception has occured loading Modules - AWSUnattachedVolumes" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSUnattachedVolumes" -Body $($_.Exception.Message)
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
  $volumeprice = $Volprice = $null
  $volumeprice = Get-PLSProduct -ServiceCode AmazonEC2 -Filter @{Type="TERM_MATCH";Field="volumeType";Value="General Purpose"},@{Type="TERM_MATCH";Field="storageMedia";Value="SSD-backed"} -Region us-east-1 
  $Volprice =  $volumeprice | ConvertFrom-Json
  Write-Log -message "Collected List price collection - $($Volprice.count)" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Accounts - AWSUnattachedVolumes" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSUnattachedVolumes" -Body $($_.Exception.Message)
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
      $VolumesinRegion = $null
      $VolumesinRegion = Get-EC2Volume -Region $region.RegionName -Credential $Creds -ErrorAction SilentlyContinue | where{-not$_.Attachment -and $_.CreateTime -lt $oneWeekAgo}
      if($error)
      {
        $error.clear
        Write-Log -message "$accoundid - $($region.RegionName) Inventory not found" -path $log -Severity Warning
      }
      else
      {
        Write-Log -message "$accoundid - $($region.RegionName) Inventory found - $($VolumesinRegion.count)" -path $log
        
        if($VolumesinRegion)
        { 
        $VolumesinRegion | ForEach-Object{
        $result =  $tags = $OwnerEmail = $volumename =   $listprice= $voltype = $listpricepermonthunit = $null
        $voltype = $_.VolumeType
        if($voltype -eq 'standard'){$voltype = 'gp2'}
        $voltype
        $listprice = $Volprice | where{$_.product.attributes.regionCode -eq $($region.RegionName) -and $_.product.attributes.volumeApiName -eq $voltype}
        $listpricepermonthunit = $listprice.terms.OnDemand.PSObject.Properties.Value.priceDimensions.PSObject.Properties.Value.pricePerUnit.USD
        Write-log -message "List price per unit - $listpricepermonthunit" -path $log
        if($listpricepermonthunit -eq $null){Write-log -message "List price per unit not found for $accoundid - $($region.RegionName) - $volumename - $($_.VolumeId)" -path $log -Severity Warning}

            $mcoll = "" | select AccountName,VolumeName,VolumeId,InstanceName,ZoneName,Size,State,ListPricePerMonth,OwnerEmail,CreateTime
            
            $tags = $_.Tags

            if(!([string]::IsNullOrEmpty($tags)))
            {
              if($tags.Key -eq "Name")
              {
                $volumename = $tags |
                Where-Object -FilterScript {
                  $_.Key -eq "Name" 
                } |
                Select-Object -ExpandProperty Value
              }
            }

            if(!([string]::IsNullOrEmpty($tags)))
            {
              if($tags.Key -eq "owner")
              {
                $OwnerEmail = $tags |
                Where-Object -FilterScript {
                  $_.Key -eq "owner" 
                } |
                Select-Object -ExpandProperty Value
              }
            }
            $mcoll.AccountName = $Accountname
            $mcoll.VolumeName = $volumename
            $mcoll.VolumeId = $_.VolumeId
            if(-not$_.Attachments){
                        $mcoll.InstanceName = "None"
            }else{
                        $mcoll.InstanceName = $_.Attachments
            }
            $mcoll.ZoneName = $_.AvailabilityZone
            $mcoll.Size= $_.Size
            $result = [decimal]$listpricepermonthunit*$_.Size
            $roundedResult = [Math]::Round($result, 2)
            $mcoll.ListPricePerMonth = $roundedResult
            $mcoll.State = $_.State
            $mcoll.CreateTime = $_.CreateTime
            $mcoll.OwnerEmail = $OwnerEmail
            $collinventory += $mcoll

          }
        }
      }
    }
  }
}

$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Medium Alert: $($collinventory.count) Amazon Volumes unattached greater than 1 week" -Attachments $Report
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AWSUnattachedVolumes" -Attachments $log