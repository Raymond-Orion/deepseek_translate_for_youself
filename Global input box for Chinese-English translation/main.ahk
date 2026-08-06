#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

global originalText := ""

; ================= 核心功能快捷键 =================

^+8:: ; Ctrl+Shift+8: 选中翻译并替换
{
    text := GetSelectedTextSafely()
    if (text != "")
        DoTranslateAndReplace(text)
}

^+7:: ; Ctrl+Shift+7: 全文翻译并替换
{
    Send("^{a}")
    Sleep(50)
    text := GetSelectedTextSafely()
    if (text != "")
        DoTranslateAndReplace(text)
}

; ================= 剪贴板与网络请求逻辑 =================

GetSelectedTextSafely()
{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^{c}")
    if !ClipWait(0.3)
    {
        A_Clipboard := ClipSaved
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

    resp := SendRequest("/translate", text)
    if (resp != "")
    {
        translatedText := ParseJsonResult(resp)
        if (translatedText != "")
        {
            ClipSaved := ClipboardAll()
            A_Clipboard := translatedText
            Send("^{v}")
            Sleep(200)
            A_Clipboard := ClipSaved 
            EnableUndoHook()
        }
    }
}

SendRequest(endpoint, text)
{
    try
    {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", "[http://127.0.0.1:15051](http://127.0.0.1:15051)" . endpoint, true)
        http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")
        
        safeText := StrReplace(text, "\\", "\\\\")
        safeText := StrReplace(safeText, "`"", "\\`"")
        safeText := StrReplace(safeText, "`n", "\\n")
        safeText := StrReplace(safeText, "`r", "\\r")
        safeText := StrReplace(safeText, "`t", "\\t")
        
        body := '{"text": "' . safeText . '"}'
        http.Send(body)
        
        if http.WaitForResponse(30)
            return http.ResponseText
    }
    return ""
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
    A_Clipboard := originalText
    Send("^{v}")
    Sleep(200)
    A_Clipboard := ClipSaved
}
