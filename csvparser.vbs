'#######################################################################
'#           CSV Parser for Parsing event logs & finding particular errors
'#           Author: Vikas Sukhija
'#           Written when I was new to scripting/was learning vbscript
'#           Tested on my win 7 machine 05/20/2013
'########################################################################
Dim openfile
Dim strnextline
Dim intsize
Dim i
intsize = 0
Const forreading = "1"
csvpath = "c:\scripts\applog.csv"
Searchstring = ","
Errorcode = "1054"

Set fso = WScript.CreateObject("Scripting.Filesystemobject")
Set openfile = fso.OpenTextFile(csvpath,forreading)
strnextline = openfile.ReadLine

Do Until openfile.AtEndOfStream
strnextline = openfile.ReadLine
If InStr(strnextline,Searchstring)Then
If InStr(strnextline,Errorcode)Then
ShowMessage(Split(strnextline,","))
WScript.Echo("all done")
End If
End If
Loop
openfile.Close

Public Sub ShowMessage(newarray)
WScript.Echo "Level:" & newArray(0)
WScript.Echo "Time:" & newarray(1)
WScript.Echo "Source:" & newArray(2)
WScript.Echo "Event ID:" & newArray(3)
WScript.Echo "Task Category:" & newArray(4)
WScript.Echo "Message1:" & newArray(5)
WScript.Echo " "
End Sub
'##########################################################################