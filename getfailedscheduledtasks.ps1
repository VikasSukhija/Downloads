<#PSScriptInfo

.VERSION 1.0

.GUID 010c8fa3-9c4a-4d41-aaf5-c20cb8f21023

.AUTHOR Vikas Sukhija

.COMPANYNAME TechWizard.cloud

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI https://techwizard.cloud/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES https://techwizard.cloud/


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
    ===========================================================================
    Created on:   	12/20/2012 10:40 AM
    Created by:   Found Some Where on Internet
    Updated by:    Vikas Sukhija
    Organization: 	
    Filename:     	GetFailedscheduledtasks.ps1
    ===========================================================================
    .DESCRIPTION
    To find fails tasks and Alert

#> 
param ()
#################variables###################################
$smtpserver = "smtp.labtest.com"
$from = "taskscheduler@labtest.com"
$to = "Reports@labtest.com"

function Get-FailedScheduledTasks
{
    Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String[]]$includepaths
  )  
    $excludedTaskResults=@(
      0, # success
      267009, # running
      267010, # disabled
      267011, # not yet ran
      267012, # There are no more runs scheduled for this task
      267014, # The last run of the task was terminated by the user
      267015, # Either the task has no triggers or the existing triggers are disabled or not set
      2147750687, # An instance of this task is already running
      3221225786, # The application terminated as a result of a CTRL+C
      1073807364, # 40010004 (hex). The system cannot open a file. This can safely be ignored as it normally pertains to CreateExplorerShellUnelevatedTask
      2147943517 # Firefox Default Browser Agent
      )
    $excludedStates=@('Disabled','Running')
    $customTasks=Get-ScheduledTask | Where-Object{ $_.State -notin $excludedStates -and $includepaths -contains ($_.TaskPath).replace("\","") }
    $failedTasks=$customTasks|Get-ScheduledTaskInfo | Where-Object{$_.LastTaskResult -notin $excludedTaskResults}
    if($failedTasks){
      return $failedTasks|Select-Object -Property * -ExcludeProperty PSComputerName,CimClass,CimInstanceProperties,CimSystemProperties
    }
  }

$getFailedScheduledTasks = Get-FailedScheduledTasks -includepaths "Scheduled","DevSolutions"

foreach($task in $getFailedScheduledTasks){
Send-MailMessage -SmtpServer $smtpserver -From $from -To $to -Subject "Failed - Task $($task.TaskName)" -Body "Failed - Task $($task.TaskName)"
}

########################################################################