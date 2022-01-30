<#	
	.NOTES
	===========================================================================
	 Created on:   	07/04/2018 
	 Created by:   	Vikas Sukhija (http://SysCloudPro.com)
	 Organization: 	
	 Filename:     	ConvertCSVTOXL.ps1
	===========================================================================
	.DESCRIPTION
		This will take CSV file as its parameter & convert it to XLS
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
   [string]$CSVPath,
	
   [Parameter(Mandatory=$True)]
   [string]$Exceloutputpath
)

####### Borrowed function from Lloyd Watkinson from script gallery##
Function Convert-NumberToA1 { 
 Param([parameter(Mandatory=$true)] 
          [int]$number) 
   
    $a1Value = $null 
    While ($number -gt 0) { 
      $multiplier = [int][system.math]::Floor(($number / 26)) 
      $charNumber = $number - ($multiplier * 26) 
      If ($charNumber -eq 0) { $multiplier-- ; $charNumber = 26 } 
      $a1Value = [char]($charNumber + 64) + $a1Value 
      $number = $multiplier 
    } 
    Return $a1Value 
  }
#############################Start converting excel#######################

$importcsv = import-csv $CSVPath
$countcolumns = ($importcsv | Get-Member | where{$_.membertype -eq "Noteproperty"}).count


#################call Excel com object ##############

$xl = new-object -comobject excel.application
$xl.visible = $false
$Workbook = $xl.workbooks.open($CSVPath)
$Worksheets = $Workbooks.worksheets
$Workbook.SaveAs($Exceloutputpath, 51)
$Workbook.Saved = $True
$xl.Quit()

#############Now format the Excel###################
timeout 10
$xl = new-object -comobject excel.application
$xl.visible = $false
$Workbook = $xl.workbooks.open($Exceloutputpath)
$worksheet1 = $workbook.worksheets.Item(1)
for ($c = 1; $c -le $countcolumns; $c++) {
    $worksheet1.Cells.Item(1, $c).Interior.ColorIndex = 39
}
$colvalue = (Convert-NumberToA1 $countcolumns) + "1"
$headerRange = $worksheet1.Range("a1", $colvalue)
$headerRange.AutoFilter() | Out-Null
$headerRange.entirecolumn.AutoFit() | Out-Null
$worksheet1.rows.item(1).Font.Bold = $True
$workbook.Save()
$workbook.Close()
$xl.Quit()

#######################################################################