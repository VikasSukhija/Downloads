<#PSScriptInfo

    .VERSION 1.0

    .GUID 51d5feb8-47af-4e08-bdb6-f62a0e9e13f5

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
    Created on:   	8/24/2023 1:46 PM
    Created by:   	Vikas Sukhija
    Organization: 	
    Filename:     	CloudAzureSQLServerDataBaseReport.ps1
    ===========================================================================

#>

<# 

    .DESCRIPTION 
    This will generate Azure SQL server database report across the organization

#> 
param()
#################logs and variables##########################
$log = Write-Log -Name "CloudAzureSQLServerDataBaseReport" -folder "logs" -Ext "log"
$Report = Write-Log -Name "CloudAzureSQLServerDataBaseReport" -folder "Report" -Ext "csv"

$smtpserver = "smtpserver"
$from = "DoNotRespond@labtest.com"
$email1 = "VikasS@labtest.com"
$erroremail = "Report@labtest.com"

$logrecyclelimit = "60"
#################get-credentials##########################
if(Test-Path -Path ".\Password.xml"){
  Write-Log -Message "Password file Exists" -path $log
}else{
  Write-Log -Message "Generate password" -path $log
  $Credential = Get-Credential 
  $Credential | Export-Clixml ".\Password.xml"
}
#############################################################
$Credential = $null
$Credential = Import-Clixml ".\Password.xml"
##################Connect to Azure####################
#######################################################################
try
{
  Write-Log -message "Start ......... Script" -path $log
  Connect-AzAccount -Credential $Credential
  Write-Log -message "Loaded All Modules" -path $log
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading Modules - CloudAzureSQLServerDataBaseReport" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - CloudAzureSQLServerDataBaseReport" -Body $($_.Exception.Message)
  break;
}

################################Query all SQL instances########################
try{
Write-Log -message "Query all SQL Servers Across all Subs" -path $log
$query = @"
Resources
| where type == "microsoft.sql/servers"
| project subscriptionId, resourceGroup, name
| order by subscriptionId asc
| summarize by subscriptionId
"@

$resourceData = Search-AzGraph -Query $query
}
catch
{
  $exception = $_.Exception.Message
  Write-Log -message "exception $exception has occured loading SQL Servers - CloudAzureSQLServerDataBaseReport" -path $log -Severity Error
  Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - CloudAzureSQLServerDataBaseReport" -Body $($_.Exception.Message)
  break;
}

##########################Loop thru all subscripotions and get SQL Instances################
$collinventory = @()
foreach ($subscription in $resourceData) {
  $sqlInstances=$null
    Select-AzSubscription -SubscriptionId $subscription.subscriptionId
        $sqlquery = @"
    Resources
    | where type == "microsoft.sql/servers"
    | where subscriptionId == '$($subscription.subscriptionId)'
    | project id,resourceGroup, name, type,location, tags
"@
    Write-Log -message "Processing ........$subscription" -path $log
    $sqlInstances = Search-AzGraph -Query $sqlquery
    foreach($sqlinstance in $sqlInstances){
    $mcoll = "" | Select ServerName,ResourceID,DomainName,Version,AdministratorName,DatabaseCount,provider,Location,PublicNetworkAccess,CreationDate,tags
    $getsqlserver=$getsqldatabase=$null
    $getsqlserver = Get-AzSqlServer -ResourceGroupName $sqlinstance.resourceGroup -ServerName $sqlinstance.name
    $getsqldatabase = Get-AzSqlDatabase -ServerName $sqlinstance.name -ResourceGroupName $sqlinstance.resourceGroup

    # Process $sqlInstances data for each subscription
    $mcoll.ServerName = $sqlinstance.name
    $mcoll.ResourceID = $sqlinstance.id

    $mcoll.DomainName = $getsqlserver.FullyQualifiedDomainName
    $mcoll.Version = $getsqlserver.ServerVersion

    $mcoll.AdministratorName = $getsqlserver.SqlAdministratorLogin
    $mcoll.DatabaseCount = $getsqldatabase.count
    $mcoll.provider = $sqlinstance.type
    $mcoll.Location = $sqlinstance.location
    $mcoll.PublicNetworkAccess = $getsqlserver.PublicNetworkAccess
    $mcoll.CreationDate = $getsqldatabase[0].CreationDate
    $mcoll.tags = $sqlinstance.tags -join ","
    $collinventory += $mcoll
    }
}
if($error){
    Write-Log -message "exception $errot has occured loading SQL Servers - CloudAzureSQLServerDataBaseReport" -path $log -Severity Error
    Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Error - CloudAzureSQLServerDataBaseReport" -Body $Error[0].ToString()
}
##########################Export to CSV################
$collinventory | Export-Csv $report -NoTypeInformation
Send-MailMessage -SmtpServer $smtpserver -From $from -To $email1 -bcc $erroremail -Subject "Report - Azure SQL Servers" -Attachments $Report
Disconnect-AzAccount
###############################Recycle logs ###############################################
Set-Recyclelogs -foldername "logs" -limit $logrecyclelimit -Confirm:$false
Write-Log -Message "Script Finished" -path $log
Send-MailMessage -SmtpServer $smtpserver -From $from -To $erroremail -Subject "Log - CloudAzureSQLServerDataBaseReport" -Attachments $log