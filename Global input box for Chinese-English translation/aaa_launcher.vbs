' ==============================================================================
' Script Name: Launcher.vbs
' Description: Foolproof silent startup for Python and AHK.
' ==============================================================================

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

' 获取当前脚本目录
scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir

' [核心修复]
' 1. 使用 cmd.exe 强行设置编码为 utf-8，解决 emoji 报错。
' 2. 使用正常的 python.exe，避免 pythonw 遇到 print() 直接崩溃。
' 3. 在末尾加上 "> NUL 2>&1" 把所有的 print 输出直接扔进系统黑洞。
' 4. 0 表示完全隐藏 cmd 窗口，False 表示后台异步运行。
pyCommand = "cmd.exe /c set PYTHONIOENCODING=utf-8 && python " & Chr(34) & scriptDir & "\main.py" & Chr(34) & " > NUL 2>&1"
WshShell.Run pyCommand, 0, False

' 启动 AHK
ahkCommand = "cmd.exe /c start " & Chr(34) & Chr(34) & " " & Chr(34) & scriptDir & "\main.ahk" & Chr(34)
WshShell.Run ahkCommand, 0, False

Set WshShell = Nothing
Set FSO = Nothing