#####################################################################
$date = get-date -format d

$time = get-date -format t

$date = $date.ToString().Replace(“/”, “-”)

$time = $time.ToString().Replace(":", "-")
$time = $time.ToString().Replace(" ", "")


$output1 = ".\" + "G_EXP_" + $date + "_" + $time + "_.csv"

########################Load SQL Snapin##############################

If ((Get-PSSnapin | where {$_.Name -match "SqlServerCmdletSnapin100"}) -eq $null)
{
  Add-PSSnapin SqlServerCmdletSnapin100
}

If ((Get-PSSnapin | where {$_.Name -match "SqlServerProviderSnapin100"}) -eq $null)
{
  Add-PSSnapin SqlServerProviderSnapin100
}
############################Invoke Sql Connection#######################
$sql_instance_name = 'Lab\DEV'
$db_name = 'testdb'
$sql_user = 'test_user'
$sql_user_pswd = 'test_user'
$query = 'select * from testdb.dbo.testList'

#########################################################################

$expcsv = invoke-sqlcmd -U $sql_user -P $sql_user_pswd -Database $db_name -Query $query -serverinstance $sql_instance_name 
if($expcsv -ne $null)
{
$expcsv | Export-Csv $output1

}
else
{
Write-Host "nothing is present in db table to export"

}

#######################################################################