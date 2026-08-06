#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

global originalText := ""

; ==========================================
; 全局气泡提示函数
; ==========================================
ShowTip(msg, duration := -2500) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), duration)
}

; ==========================================
; 开发辅助：保存脚本自动重启
; ==========================================
if (A_Args.Length > 0 && A_Args[1] == "/reloaded") {
    ShowTip("✅ 脚本已重新加载")
}

#HotIf WinActive(A_ScriptName)
~^s:: {
    Sleep(200)
    Run('"' . A_AhkPath . '" "' . A_ScriptFullPath . '" /reloaded')
    ExitApp()
}
#HotIf

; ================= 核心功能快捷键 =================

^+8:: ; Ctrl+Shift+8: 选中翻译并替换
{
    text := GetSelectedTextSafely()
    if (text != "")
        DoTranslateAndReplace(text)
}

^+7:: ; Ctrl+Shift+7: 全文翻译并替换
{
    Send("^a")
    Sleep(100)
    text := GetSelectedTextSafely()
    if (text != "")
        DoTranslateAndReplace(text)
}

; ================= 剪贴板与网络请求逻辑 =================

GetSelectedTextSafely()
{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^c") ; 使用标准的 Ctrl+C

    if !ClipWait(0.5) ; 给剪贴板 0.5 秒的缓冲时间
    {
        A_Clipboard := ClipSaved
        ShowTip("⚠️ 未检测到选中文本")
        return ""
    }

    text := A_Clipboard
    A_Clipboard := ClipSaved
    return text
}

DoTranslateAndReplace(text)
{
    global originalText
    originalText := text

    ShowTip("⏳ 正在请求深度翻译...")

    resp := SendRequest("/translate", text)
    if (resp == "") {
        ShowTip("❌ 翻译失败：无法连接到本地服务")
        return
    }

    translatedText := ParseJsonResult(resp)
    if (translatedText != "")
    {
        ClipSaved := ClipboardAll()
        A_Clipboard := ""
        A_Clipboard := translatedText
        ClipWait(0.5) ; 确保文本完全写入剪贴板

        Send("^v") ; 使用标准的 Ctrl+V
        Sleep(200)
        A_Clipboard := ClipSaved 
        EnableUndoHook()

        ShowTip("✅ 翻译完成 (按 Ctrl+Z 撤销)")
    }
    else {
        ; 【新增Debug弹窗】：强制显示 Python 后端返回的真实报文
        MsgBox("【抓到报错了】Python 后端返回的具体信息如下：`n`n" . resp, "后端报错日志", 16)
        ShowTip("❌ 翻译失败：API 响应异常")
    }
}

SendRequest(endpoint, text)
{
    try
    {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        ; 【核心修复】将 true 改为 false，强制使用同步请求，耐心等待后台返回结果！
        http.Open("POST", "http://127.0.0.1:15051" . endpoint, false)
        http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")

        safeText := StrReplace(text, "\", "\\")
        safeText := StrReplace(safeText, "`"", "\`"")
        safeText := StrReplace(safeText, "`n", "\n")
        safeText := StrReplace(safeText, "`r", "\r")
        safeText := StrReplace(safeText, "`t", "\t")

        body := '{"text": "' . safeText . '"}'
        http.Send(body)

        return http.ResponseText
    } catch {
        return ""
    }
}

ParseJsonResult(jsonStr)
{
    try {
        html := ComObject("htmlfile")
        html.write("<meta http-equiv='X-UA-Compatible' content='IE=edge'>")
        return html.parentWindow.eval("(" . jsonStr . ").result")
    } catch {
        return ""
    }
}

; ================= 撤销功能 (Ctrl+Z) =================

EnableUndoHook()
{
    Hotkey("^z", UndoAction, "On")
    SetTimer(DisableUndoHook, -30000) ; 30秒后关闭撤销钩子
}

DisableUndoHook()
{
    SetTimer(DisableUndoHook, 0)
    try Hotkey("^z", "Off")
}

UndoAction(ThisHotkey)
{
    global originalText
    DisableUndoHook()
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := originalText
    ClipWait(0.5)
    Send("^v")
    Sleep(200)
    A_Clipboard := ClipSaved
    ShowTip("↩️ 已恢复原文")
}
