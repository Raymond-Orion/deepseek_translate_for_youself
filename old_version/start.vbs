Set oShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' 获取当前脚本所在的绝对路径目录
strScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

' 1. 隐蔽启动 Python API 服务
' (通过 cmd /c cd /d 先切换目录，确保 python 能正确读取到同目录下的 .env 文件，0 表示隐藏黑窗口)
oShell.Run "cmd /c cd /d """ & strScriptDir & """ && python server.py", 0, False

' 2. 隐蔽启动 AutoHotkey 客户端
' (直接调用脚本的绝对路径，系统会自动使用 AHK 解释器运行它)
oShell.Run "cmd /c """ & strScriptDir & "\client.ahk""", 0, False
