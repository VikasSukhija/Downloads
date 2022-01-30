'###################################################################
'##           Script to check the status of machines              ##
'##           Author: Unknown                  		          ##
'##           Date: 03-30-2012                       		  ##
'##           modified by: Vikas Sukhija                          ##
'###################################################################

'# call excel applicationin visible mode

Set objExcel = CreateObject("Excel.Application")
 
objExcel.Visible = True
 
objExcel.Workbooks.Add
 
intRow = 2
 
'# Define Labels 
 
objExcel.Cells(1, 1).Value = "Machine Name"
 
objExcel.Cells(1, 2).Value = "Results"
 
 
'# Create file system object for reading the hosts from text file


Set Fso = CreateObject("Scripting.FileSystemObject")
 
Set InputFile = fso.OpenTextFile("MachineList.Txt")
 
'# Loop thru the text file till the end 
 
Do While Not (InputFile.atEndOfStream)
 
HostName = InputFile.ReadLine
  
'# Create shell object for Pinging the host machines

 
Set WshShell = WScript.CreateObject("WScript.Shell")
 
Ping = WshShell.Run("ping -n 1 " & HostName, 0, True)
 
 
objExcel.Cells(intRow, 1).Value = HostName
 
'# use switch case for checking the machine updown status
 
Select Case Ping
 
Case 0 objExcel.Cells(intRow, 2).Value = "Up"
 
Case 1 objExcel.Cells(intRow, 2).Value = "Down"
 
End Select
 
 
 
intRow = intRow + 1
 
Loop
 
'# Format the excel
 
objExcel.Range("A1:B1").Select
 
objExcel.Selection.Interior.ColorIndex = 19
 
objExcel.Selection.Font.ColorIndex = 11
 
objExcel.Selection.Font.Bold = True
 
objExcel.Cells.EntireColumn.AutoFit

'####################################################################
