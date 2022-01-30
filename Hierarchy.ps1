######################################################################################
# 			Author: Vikas Sukhija
# 			Date:- 11/14/2012
#Description:- This script  will use quest shell & grab the hierarchy details from AD
#Prerequisites :- Excel & Quest Shell
######################################################################################
Start-Transcript

# call excel for writing the results

$objExcel = new-object -comobject excel.application 
$workbook = $objExcel.Workbooks.Add()
$worksheet=$workbook.ActiveSheet 
$objExcel.Visible = $False
$cells=$worksheet.Cells

# define top level cell

$cells.item(1,1)="level0"
$cells.item(1,2)="title0"
$cells.item(1,3)="level1"
$cells.item(1,4)="title1"
$cells.item(1,5)="level2"
$cells.item(1,6)="title2"
$cells.item(1,7)="level3"
$cells.item(1,8)="title3"
$cells.item(1,9)="level4"
$cells.item(1,10)="title4"
$cells.item(1,11)="level5"
$cells.item(1,12)="title5"
$cells.item(1,13)="level6"
$cells.item(1,14)="title6"
$cells.item(1,15)="level7"
$cells.item(1,16)="title7"
$cells.item(1,17)="level8"
$cells.item(1,18)="title8"
$cells.item(1,19)="level9"
$cells.item(1,20)="title9"
$cells.item(1,21)="level10"
$cells.item(1,22)="title10"

#intitialize row out of the loop

$row = 1

#import quest management Shell

if ( (Get-PSSnapin -Name Quest.ActiveRoles.ADManagement -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PsSnapin Quest.ActiveRoles.ADManagement 
}


$data = import-csv .\users.csv

#loop thru users

foreach ($i in $data)
 
{

#initialize column within the loop so that it always loop back to column 1
$col = 1
$user=get-qaduser $i.username
Write-host "Processing.................................$user"
$manager = $user.manager
$row++
# loop until the manager field is null
Do

{ 

# get user id that will be inserted in level columns

$userid = $user.DisplayName
$cells.item($row,$col) = $userid
$col++
#get titles that will be inserted in title columns
$title = $user.title
$cells.item($row,$col) = $title
$col++
$user = get-qaduser $manager
$manager = $user.manager

} While($manager -ne $null)


}

#formatting excel

$range = $objExcel.Range("A2").CurrentRegion
$range.ColumnWidth = 30
$range.Borders.Color = 0
$range.Borders.Weight = 2
$range.Interior.ColorIndex = 37
$range.Font.Bold = $false
$range.HorizontalAlignment = 3

# Headings in Bold

$cells.item(1,1).font.bold=$True
$cells.item(1,2).font.bold=$True
$cells.item(1,3).font.bold=$True
$cells.item(1,4).font.bold=$True
$cells.item(1,5).font.bold=$True
$cells.item(1,6).font.bold=$True
$cells.item(1,7).font.bold=$True
$cells.item(1,8).font.bold=$True
$cells.item(1,9).font.bold=$True
$cells.item(1,10).font.bold=$True
$cells.item(1,11).font.bold=$True
$cells.item(1,12).font.bold=$True
$cells.item(1,13).font.bold=$True
$cells.item(1,14).font.bold=$True
$cells.item(1,15).font.bold=$True
$cells.item(1,16).font.bold=$True
$cells.item(1,17).font.bold=$True
$cells.item(1,18).font.bold=$True
$cells.item(1,19).font.bold=$True
$cells.item(1,20).font.bold=$True
$cells.item(1,21).font.bold=$True
$cells.item(1,22).font.bold=$True

#save the excel file

$filepath = "c:\scripts\Hierarchy.xlsx"
$workbook.saveas($filepath)
$workbook.close()
$objExcel.Quit()

Stop-Transcript
##############################################################################################

