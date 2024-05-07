<#PSScriptInfo

    .VERSION 1.1

    .GUID a7016e19-4499-46b9-84a9-cf3d7053a4e2

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
    Created on:   	2/26/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	AWSS3BucketsReport.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This solution will generate S3 buckets inventory

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "AWSS3BucketsReport" -folder "logs" -Ext "log"
$Failedlog = Write-Log -Name "FailedAccounts" -folder "logs" -Ext "log"
$Report = Write-Log -Name "AWSS3BucketsReport" -folder "Report" -Ext "csv"
$logrecyclelimit = "60"
$email1 =  "Vikas@labtest.com"
##################Admin params##########################
$smtpserver = "smtpserver"
$erroremail = "reports@labtest.com"
$from = "DoNotRespond@labtest.com"
######################Spo Cet Auth#########################
$AccessKey = "Access Key"
$SecretKey = "Secret Key"
###########################################################
<#
    .SYNOPSIS
        Provides maximum or highest average bucket size in gibibytes and number of objects via AWS CloudWatch measurements for a specific S3 bucket or all buckets over a specificed period of days.

    .DESCRIPTION
        Accepts a single bucket name or an array of bucket names via the pipline to pass to AWS CloudWatch to retrieve metrics for all (default) or selected storage classes.

    .PARAMETER BucketName
        Lower-case name of S3 bucket.

    .PARAMETER StorageClass
        One of StandardStorage | StandardIAStorage | ReducedRedundancyStorage. Defaults to all storage classes. Results for storage class AllStorageTypes are always returned in order to provide the number of objects.

    .PARAMETER AWSProfile
        String containing name of credentals created via New-AWSCredential. Defaults to credentials stored in default AWS profile, that is whatever is authorized when no credentials are supplied.

    .PARAMETER Days
        The number of days for which to collect average or maximum CloudWatch metrics for S3 buckets. Defaults to 5.

    .PARAMETER Statistic
        The case-sensitive CloudWatch statistic to retireve. Must be one of 'Maximum' or 'Average'. Defaults to 'Average'. 'Average' returns highest average over the number of days selected.

    .INPUTS
        System.String

    .OUTPUTS
        System.Management.Automation.PSObject:
                Bucket = Name of S3 Bucket
                SizeGiB = Size in gibibytes of contents of bucket by storage class
                NumObjects = Number of S3 objects in bucket across ALL storage classes
                StorageClass = bucket storage class (exclusing GLAICER class)
    .EXAMPLE
        PS C:\> Get-S3BucketSize

        Outputs to the pipline a collection of type PSObject that lists the average bucket size and number of objects in all buckets over the previous five days. Uses the default AWS credential profile.

    .EXAMPLE
        PS C:\> Get-S3BucketSize -BucketName 'BucketName' -Statistic 'Maximum' -AWSProfile 'myprofile'

        Outputs to the pipline a (single member) collection of type PSObject that lists the maximum bucket size and number of objects over the previous five days. Selects buckets based on 'myprofile'.

    .EXAMPLE
        PS C:\> Get-S3BucketSize -BucketName 'BucketName' -Days 14

        Outputs to the pipline a (single member) collection of type PSObject that lists the maximum average bucket size and number of objects over the previous 14 days. Selects buckets based on 'myprofile'.

    .EXAMPLE
        PS C:\> Get-S3BucketSize | Measure-Object -Property SizeGiB -Sum

        Sums the maximum average size over the last five days of all S3 buckets.
    
    .EXAMPLE
        PS C:\> Get-S3BucketSize | Measure-Object -Property NumObjects -Sum

        Sums the maximum average number of objects over the last five days of all S3 buckets.

    .EXAMPLE
        PS C:\> Get-S3BucketSize -StorageClass StandardStorage | Measure-Object -Property SizeGiB -Sum

        Pipes the maximum average size of StandardStorage over the last five days of all S3 buckets available to the current profile to Measure-Object which sums the total size of all S3 objects in those buckets.

    .EXAMPLE
        PS C:\> Import-Csv .\lisofbuckets.csv | Get-S3BucketSize

        Accepts from pipeline a list of buckets to be retrieved for measurement. The .csv file can be easily created with Get-S3Bucket | Export-Csv .\listofbuckets.csv and edited as required.

    .EXAMPLE
        PS C:\> Get-S3Bucket | Get-S3BucketSize

        Outputs to the pipline a collection of all S3 buckets' size and number of objects. This is equivalent to Get-S3BucketSize since it will also invoke Get-S3Bucket when -BucketName is omitted.


.NOTES
        For more information on S3 metrics in CloudWatch, see http://docs.aws.amazon.com/AmazonS3/latest/dev/cloudwatch-monitoring.html

        (c) 2016 Air11 Technology LLC -- licensed under the Apache OpenSource 2.0 license, https://opensource.org/licenses/Apache-2.0
        Author's blog: https://www.yobyot.com
#>
function Get-S3BucketSize
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
                   Position = 0,
                   HelpMessage = 'Lower-case name of S3 bucket')]
        [System.String[]]$BucketName = 'All',
        [Parameter(HelpMessage = 'Specify storage class ')]
        [System.String]$StorageClass,
        [Parameter(HelpMessage = 'Enter the name of the AWS credential profile to be used')]
        [System.String]$AWSProfile,
        [Parameter(HelpMessage = 'Enter an integer for the number of days to collect metrics')]
        [ValidateRange(1, 14)]
        [System.Int16]$Days = 5,
        $region,
        [System.String]$Statistic = 'Average'
    )
    
    begin
    {
        try
        {
            $obj = [ordered]@{
                'Bucket' = ''
                'SizeGiB' = ''
                'NumObjects' = ''
                'StorageClass' = ''
            }
            $results = @()
            $daysAgo = (Get-Date ([datetime](Get-Date).AddDays(- $Days)) -Format s) # Date formats for Get-CWMetricStatistics MUST be in ISO format
            $today = Get-Date -Format s # Date formats for Get-CWMetricStatistics MUST be in ISO format
            #if ($AWSProfile) { Set-AWSCredentials -ProfileName $AWSProfile }
            if ($Statistic -cnotmatch '(Maximum|Average)\b') { $Statistic = "Average" }
            Write-Verbose "Today=$today, DaysAgo=$daysAgo, AWSProfile=$AWSProfile, Statistic=$Statistic"
        }
        catch
        {
            "An error occurred: $Error"
        }
    }
    process
    {
        try
        {
            
            switch ($BucketName)
            {
                'All' {
                    $BucketNameStrings = Get-S3Bucket -Region $region -Credential $creds | Select-Object -ExpandProperty BucketName
                    
                    foreach ($b in $BucketNameStrings)
                    {
                        
                        switch ("$StorageClass")
                        {
                            "StandardStorage" {
                                $results += (getBucketSize "$b" 'StandardStorage')
                                
                            }
                            "StandardIASStorage"  {
                                $results += (getBucketSize "$b" 'StandardIAStorage')
                            }
                            "ReducedRedundancyStorage" {
                                $results += (getBucketSize "$b" 'ReducedRedundancyStorage')
                            }
                            default
                            {
                                #Get all classes
                                $results += getBucketSize $b 'StandardStorage'
                                $results += getBucketSize $b 'StandardIAStorage'
                                $results += getBucketSize $b 'ReducedRedundancyStorage'
                            }
                        }
                        $results += (getBucketNumObjects $b)
                    }
                    
                }
                
                ($BucketName -ne 'All')
                {
                    
                    switch ("$StorageClass")
                    {
                        "StandardStorage" {
                            $results += (getBucketSize $BucketName 'StandardStorage')
                            
                        }
                        "StandardIAStorage"  {
                            $results += (getBucketSize $BucketName 'StandardIAStorage')
                        }
                        "ReducedRedundancyStorage" {
                            $results += (getBucketSize $BucketName 'ReducedRedundancyStorage')
                        }
                        default
                        {
                            #Get all classes
                            $results += (getBucketSize $BucketName 'StandardStorage')
                            $results += (getBucketSize $BucketName 'StandardIAStorage')
                            $results += (getBucketSize $BucketName 'ReducedRedundancyStorage')
                        }
                    }
                    $results += (getBucketNumObjects $BucketName)
                }
                default { Write-Verbose "Neither 'All' nor individual bucket selected; big problem since default bucket name is 'All' " }
            }
        }
        catch
        {
            "An error occurred: $Error"
        }
    }
    end
    {
        try
        {
            Write-Output $results
            Write-Verbose "Done"
        }
        catch
        {
            "An error occurred: $Error"
        }
    }
}
function getBucketSize ($bname, $stgclass)
{
    Write-Verbose "getBucketSize entered with $bname and storage class $stgclass"
    
    $metricSize = Get-CWMetricStatistics -Credential $creds -region $region -Namespace 'AWS/S3' -MetricName 'BucketSizeBytes' `
                                         -Dimension @(@{ Name = 'BucketName'; Value = "$bname" }; @{ Name = 'StorageType'; Value = "$stgclass" }) `
                                         -Statistic $Statistic -Period 86400 -UtcStartTime $daysAgo -UtcEndTime $today
    $maxSize = '{0:N2}' -f (($metricSize.Datapoints | Measure-Object -Property $Statistic -Maximum).Maximum / 1GB)
    
    $functionObj = New-Object -TypeName System.Management.Automation.PSObject -Property $obj
    $functionObj.Bucket = [string]$bname
    $functionObj.SizeGiB = [decimal]$maxSize
    $functionObj.NumObjects = ''
    $functionObj.StorageClass = $stgclass
    $functionObj
}
function getBucketNumObjects ($bname)
{
    Write-Verbose "getBucketNumObjects entered with $bname and storage class $stgclass"
    
    $metricNumObjects = Get-CWMetricStatistics -Credential $creds -region $region -Namespace 'AWS/S3' -MetricName 'NumberOfObjects' `
                                               -Dimension @(@{ Name = 'BucketName'; Value = "$bname" }; @{ Name = 'StorageType'; Value = 'AllStorageTypes' }) `
                                               -Statistic $Statistic -Period 86400 -UtcStartTime $daysAgo -UtcEndTime $today
    $numObjects = (($metricNumObjects.Datapoints | Measure-Object -Property $Statistic -Maximum).Maximum)
    if (!$numObjects) { $numObjects = 0 }
    
    $functionObj = New-Object -TypeName System.Management.Automation.PSObject -Property $obj
    $functionObj.Bucket = [string]$bname
    $functionObj.SizeGiB = ''
    $functionObj.NumObjects = $numObjects
    $functionObj.StorageClass = 'AllStorageTypes'
    
    $functionObj
}
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
  Write-Log -message "exception $exception has occured loading Modules - AWSS3BucketsReport" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSS3BucketsReport" -Body $($_.Exception.Message)
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
  Write-Log -message "exception $exception has occured loading Accounts - AWSS3BucketsReport" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - AWSS3BucketsReport" -Body $($_.Exception.Message)
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
      $error.clear()
      $buckets = $null
      $buckets = Get-S3Bucket -Credential $Creds
      if($error)
      {
        $error.clear
        Write-Log -message "$accoundid - $($region.RegionName) Inventory not found" -path $log -Severity Warning
      }
      else
      {
        Write-Log -message "$accoundid - $($region.RegionName) Inventory found - $($buckets.count)" -path $log
        
        if($buckets)
        { 
        $buckets | ForEach-Object{
        $mcoll = "" | select Name,Day,AccountName,OwnerId,StorageinGB,Tags,Access,ObjectCount,RegionName
        $objects = $totalSizeGB =  $tags = $BucketName=$S3BucketSize=$getbucketlocation = $NumObjects= $access = $null
        $BucketName = $_.BucketName
        $getbucketlocation = $(Get-S3BucketLocation -BucketName $BucketName -credential $Creds).Value
        switch($getbucketlocation)
        {
          "EU" { $regionname = "eu-west-1" }
          "$null" { $regionname = "us-east-1" }
          default { $regionname = $getbucketlocation}
        }
        $S3BucketSize = get-S3bucketsize -BucketName $BucketName -Region $regionname -StorageClass StandardStorage
        $NumObjects = $($S3BucketSize.Where{$_.StorageClass -eq  "AllStorageTypes"}).NumObjects
        $totalSizeGB = $($S3BucketSize.Where{$_.StorageClass -eq  "StandardStorage"}).SizeGiB
        Write-Log -message "BucketName - $BucketName BucketLocation -  $regionname Objectscount - $NumObjects - $totalSizeGB" -path $log
        $Tags = Get-S3BucketTagging -BucketName $BucketName  -credential $Creds -Region $regionname
        $mcoll.Name = $BucketName
        $mcoll.Day = (Get-Date).ToString("MM/dd/yyyy")
        $mcoll.AccountName = $Accountname
        $mcoll.OwnerId = $accoundid
        $mcoll.StorageinGB = $totalSizeGB
        $mcoll.Tags = ($tags | ConvertTo-csv -NoTypeInformation -Delimiter ":") -join ","
        $Access = get-S3publicAccessBlock -BucketName $BucketName -credential $Creds -Region $regionname
        if($error[0] -like "*Access Denied*"){
          $mcoll.Access = "UnKnown"
        }
        if($Access.BlockPublicAcls -eq $false){
          $mcoll.Access = "Public"
        }
        if($Access.BlockPublicAcls -eq $True){
          $mcoll.Access = "Not Public"
        }
        if($Access -eq $null){
          $mcoll.Access = "Not Public"
        }
        $mcoll.ObjectCount = $NumObjects
        $mcoll.RegionName = $regionname
        $collinventory += $mcoll
          }
        }
      }
  }
}

$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Report: AWS S3 Report - Buckets $($collinventory.count)" -Attachments $Report
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - AWSS3BucketsReport" -Attachments $log