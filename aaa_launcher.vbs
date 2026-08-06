' ==============================================================================
' Script Name: aaa_launcher.vbs
' Description: Foolproof silent startup for Python and AHK.
' ==============================================================================

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir

pyCommand = "cmd.exe /c set PYTHONIOENCODING=utf-8 && python " & Chr(34) & scriptDir & "\main.py" & Chr(34) & " > NUL 2>&1"
WshShell.Run pyCommand, 0, False

ahkCommand = "cmd.exe /c start " & Chr(34) & Chr(34) & " " & Chr(34) & scriptDir & "\main.ahk" & Chr(34)
WshShell.Run ahkCommand, 0, False

Set WshShell = Nothing
Set FSO = Nothing
