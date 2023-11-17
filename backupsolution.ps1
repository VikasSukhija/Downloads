###############################################################################
#		This script  will copy safesenders from DFS
#		Author: Vikas Sukhija
# 		Date:- 05/11/2015
#       updated: 11/15/2023
#       BackupSolution.ps1
#       Require vsadmin
###########################Variables#########################################
$log = Write-Log -Name "BackupSolution-Log" -folder "logs" -Ext "log"

$Dname = ((get-date).AddDays(0).toString('yyyyMMdd'))
$dirName = "BackupSolution_$Dname" 


$SourcePath = "\\Server1\e$\Folder1"
$DestinationPath = "\\Server2\e$\backupfolder"

$destination = $DestinationPath+ "\" + $dirName

##########################Backup###########################################
Write-Log -message "Start...............Script" -path $log
try { 
    Write-Log -message "Creating Destination Directory - $dirName" -path $log
    new-item -path $DestinationPath -name $dirName -type directory
    Write-Log -message "Start Backup from $SourcePath  to $destination" -path $log
    Copy-item -path $SourcePath -Destination $destination -Recurse
    Write-Log -message "Backup .......... Finished" -path $log
    if($error){
    Write-Log -Message "Error occured - $error" -path $log -Severity error
    }
    } 
    catch  
    {  
        $exception = $_.Exception
        Write-Log -Message "Exception Occured - $exception" -path $log -Severity error
    }  

Write-Log -message "Script .......... Finished" -path $log
##############################################################################