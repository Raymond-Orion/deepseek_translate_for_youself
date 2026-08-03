#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================================
; === 1. 自动请求管理员权限 (高权限运行) ===
; ==========================================
if not A_IsAdmin {
    Try {
        Run '*RunAs "' A_ScriptFullPath '"'
        ExitApp()
    }
}

ServerURL := "http://127.0.0.1:8989/translate"
Global ExplainURL := "http://127.0.0.1:8989/explain"
Global g_ExplainGui := ""

; 全局划词图标 GUI 与状态控制
Global g_IconGui := ""
Global g_SelectedText := ""
Global g_MouseDownX := 0
Global g_MouseDownY := 0

; ==========================================
; === 全局状态记录，用于 Ctrl+Z 完美复原 ===
; ==========================================
Global g_OriginalText := ""
Global g_IsSelectAll := false
Global g_AwaitUndo := false

~*LButton::
{
    CancelUndo()
    ; 记录鼠标按下时的坐标，用于判断拖拽距离
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    Global g_MouseDownX := x
    Global g_MouseDownY := y
    
    ; 如果图标已存在，点击图标以外的地方自动销毁图标
    if (g_IconGui != "") {
        MouseGetPos(,, &targetHwnd)
        if (targetHwnd != g_IconGui.Hwnd) {
            DestroyIconGui()
        }
    }
}

~*RButton::
{
    CancelUndo()
    DestroyIconGui()
}

CancelUndo() {
    global g_AwaitUndo
    g_AwaitUndo := false
}

; ==========================================
; === 2. 划词核心监听 (鼠标抬起触发 - 极严防误触) ===
; ==========================================
~LButton Up::
{
    ; 防误触 1：按住 Ctrl / Alt / Win 等修饰键拖拽（如 VSCode 多光标选择）时不触发
    if GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P") {
        return
    }

    ; 防误触 2：拖拽距离过小（低于 10 像素，视为普通点击/双击空行/微小抖动）不触发
    CoordMode("Mouse", "Screen")
    MouseGetPos(&upX, &upY)
    dist := Sqrt((upX - g_MouseDownX)**2 + (upY - g_MouseDownY)**2)
    if (dist < 10) {
        return
    }

    ; 防误触 3：文本光标形态 (IBeam) 下微小移动不触发（防止在 VSCode/IDE 中改代码或点空行时弹窗）
    if (A_Cursor == "IBeam" && dist < 15) {
        return
    }

    ; 稍作停顿，等待系统选中状态稳定
    Sleep 35

    ; 静默备份剪贴板并尝试提取文本
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"

    ; 如果 250ms 内没抓到文本，说明未选中任何内容，恢复剪贴板并退出
    if !ClipWait(0.25, 1) {
        RestoreClipboard(ClipSaved)
        return
    }

    CapturedText := A_Clipboard

    ; 防误触 4【核心】：严密检查内容！
    ; 如果选中的是空字符串、纯空格、纯 Tab、纯换行或全空白代码行，绝对不触发！
    if (CapturedText == "" || RegExMatch(CapturedText, "^\s*$")) {
        RestoreClipboard(ClipSaved)
        return
    }

    ; 防误触 5：只选中了单字符且为常见标点/括号（如在代码里点了个 ; 或 }），跳过
    CleanText := Trim(CapturedText, " `t`r`n")
    if (StrLen(CleanText) == 1 && RegExMatch(CleanText, '^[;,\.\:\(\)\{\}\[\]"]$')) {
        RestoreClipboard(ClipSaved)
        return
    }

    ; 安全恢复剪贴板
    RestoreClipboard(ClipSaved)

    ; 校验通过：保存文本并显示 🔍 悬浮图标
    Global g_SelectedText := CleanText
    ShowHoverIcon(upX + 12, upY + 12)
}

; ==========================================
; === 3. 浅色微型悬浮 🔍 图标 GUI 设计 ===
; ==========================================
ShowHoverIcon(x, y)
{
    Global g_IconGui
    DestroyIconGui()

    ; 创建无边框微型 GUI (32x32)
    g_IconGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner", "HoverIcon")
    g_IconGui.BackColor := "FFFFFF" ; 纯白背景

    ; 添加 🔍 图标文本按钮
    BtnText := g_IconGui.Add("Text", "x0 y0 w32 h32 Center +BackgroundTrans c333333", "🔍")
    BtnText.SetFont("s13", "Segoe UI Emoji")

    ; 悬停与点击事件绑定
    BtnText.OnEvent("Click", OnIconClick)
    
    ; 窗口显示
    g_IconGui.Show("x" x " y" y " w32 h32 NoActivate")
    
    ; 监听鼠标悬停动作变色
    OnMessage(0x0200, WM_MOUSEMOVE)

    ; 3.5秒内无操作自动消隐
    SetTimer DestroyIconGui, -3500
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd)
{
    Global g_IconGui
    if (g_IconGui != "" && hwnd == g_IconGui.Hwnd) {
        g_IconGui.BackColor := "E2E8F0" ; Hover 时变为浅灰色
    }
}

OnIconClick(*)
{
    Global g_SelectedText
    TextToRun := g_SelectedText
    DestroyIconGui()
    
    if (TextToRun != "") {
        ProcessExplainText(TextToRun)
    }
}

DestroyIconGui()
{
    Global g_IconGui
    if (g_IconGui != "") {
        Try g_IconGui.Destroy()
        g_IconGui := ""
    }
    SetTimer DestroyIconGui, 0
}

; ========== 快捷键定义 ==========

^+8::
{
    Send "{Ctrl up}{Shift up}"
    ProcessTranslation(false)
}

^+7::
{
    Send "{Ctrl up}{Shift up}"
    ProcessTranslation(true)
}

; Ctrl + Shift + 9: 保留快捷键触发逻辑
^+9::
{
    Send "{Ctrl up}{Shift up}"
    ProcessExplain()
}

; ==========================================
; === 划词流式解释核心逻辑 (内嵌 HTML 渲染) ===
; ==========================================

ProcessExplain()
{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    
    if !ClipWait(0.5, 1) { 
        ShowYellowTip("未检测到文本")
        RestoreClipboard(ClipSaved)
        return
    }
    
    TextToExplain := A_Clipboard
    RestoreClipboard(ClipSaved)
    
    if (TextToExplain == "" || RegExMatch(TextToExplain, "^\s*$")) {
        ShowYellowTip("未检测到有效文本")
        return
    }

    ProcessExplainText(Trim(TextToExplain, " `t`r`n"))
}

ProcessExplainText(TextToExplain)
{
    Global ExplainURL, g_ExplainGui
    
    ; 准备 深色GUI
    if (g_ExplainGui != "") {
        Try g_ExplainGui.Destroy()
    }
    
    g_ExplainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "DeepSeek Explain")
    g_ExplainGui.BackColor := "1E1E1E" 
    
    TitleText := g_ExplainGui.Add("Text", "x15 y10 w750 h20 +BackgroundTrans c888888", "正在深度解析中...")
    TitleText.SetFont("s10", "Microsoft YaHei")
    
    CloseBtn := g_ExplainGui.Add("Text", "x770 y5 w20 h20 +Center +BackgroundTrans cA0A0A0", "X")
    CloseBtn.SetFont("s14 bold", "Consolas")
    CloseBtn.OnEvent("Click", (*) => g_ExplainGui.Destroy())
    
    wbCtrl := g_ExplainGui.Add("ActiveX", "x10 y35 w780 h455 Hidden", "Shell.Explorer")
    WB := wbCtrl.Value
    
    g_ExplainGui.OnEvent("Escape", (*) => g_ExplainGui.Destroy())
    OnMessage(0x0201, WM_LBUTTONDOWN)
    
    g_ExplainGui.Show("w800 h500 NoActivate Center")
    
    HTML := "<!DOCTYPE html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'>"
    HTML .= "<style>"
    HTML .= "body { background-color: #1E1E1E; color: #E0E0E0; font-family: 'Times New Roman', 'Microsoft YaHei', sans-serif; font-size: 17px; line-height: 1.55; padding: 15px; margin: 0; border: none; overflow-y: auto; }"
    HTML .= "strong, b { color: #FFFFFF; font-weight: bold; }"
    HTML .= "em { font-style: italic; color: #A8C7FA; }"
    HTML .= "table { border-collapse: collapse; width: 100%; margin-top: 6px; margin-bottom: 6px; font-size: 15px; }"
    HTML .= "th, td { border: 1px solid #444444; padding: 8px 12px; text-align: left; }"
    HTML .= "th { background-color: #2D2D2D; color: #FFFFFF; font-weight: bold; }"
    HTML .= "tr:nth-child(even) { background-color: #252526; }"
    HTML .= "::-webkit-scrollbar { width: 8px; } ::-webkit-scrollbar-track { background: #1E1E1E; } ::-webkit-scrollbar-thumb { background: #555; border-radius: 4px; }"
    HTML .= "html { scrollbar-face-color: #555; scrollbar-track-color: #1E1E1E; scrollbar-shadow-color: #1E1E1E; scrollbar-3dlight-color: #1E1E1E; }"
    HTML .= "</style>"
    HTML .= "<script>"
    HTML .= "function updateContent(text) {"
    HTML .= "    var html = text.replace(/\r/g, '')"
    HTML .= "        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');"
    HTML .= "    var lines = html.split('\n');"
    HTML .= "    var inTable = false;"
    HTML .= "    var processedLines = [];"
    HTML .= "    for (var i = 0; i < lines.length; i++) {"
    HTML .= "        var line = lines[i].replace(/(^\s*)|(\s*$)/g, '');"
    HTML .= "        if (line.charAt(0) === '|' && line.charAt(line.length - 1) === '|') {"
    HTML .= "            var cells = line.split('|').slice(1, -1);"
    HTML .= "            if (cells.length > 0 && cells[0].replace(/(^\s*)|(\s*$)/g, '').match(/^[-\s:]+$/)) { continue; }"
    HTML .= "            var rowHtml = '<tr>';"
    HTML .= "            for (var j = 0; j < cells.length; j++) {"
    HTML .= "                var cellTag = (!inTable) ? 'th' : 'td';"
    HTML .= "                rowHtml += '<' + cellTag + '>' + cells[j].replace(/(^\s*)|(\s*$)/g, '') + '</' + cellTag + '>';"
    HTML .= "            }"
    HTML .= "            rowHtml += '</tr>';"
    HTML .= "            if (!inTable) {"
    HTML .= "                while (processedLines.length > 0 && processedLines[processedLines.length - 1] === '') { processedLines.pop(); }"
    HTML .= "                processedLines.push('<table>');"
    HTML .= "                inTable = true;"
    HTML .= "            }"
    HTML .= "            processedLines.push(rowHtml);"
    HTML .= "        } else {"
    HTML .= "            if (inTable) { processedLines.push('</table>'); inTable = false; }"
    HTML .= "            processedLines.push(lines[i]);"
    HTML .= "        }"
    HTML .= "    }"
    HTML .= "    if (inTable) { processedLines.push('</table>'); }"
    HTML .= "    html = processedLines.join('\n');"
    HTML .= "    html = html"
    HTML .= "        .replace(/\n*###\s+(.*)/g, '<div style=\'font-size: 18px; font-weight: bold; color: #FFFFFF; margin-top: 10px; margin-bottom: 2px;\'>$1</div>')" 
    HTML .= "        .replace(/\n*##\s+(.*)/g, '<div style=\'font-size: 20px; font-weight: bold; color: #FFFFFF; margin-top: 12px; margin-bottom: 2px;\'>$1</div>')" 
    HTML .= "        .replace(/(^|\n)\s*\*\s+(.*)/g, '$1<div style=\'margin-left: 20px; color: #CCCCCC;\'>&#8226; $2</div>')" 
    HTML .= "        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')"
    HTML .= "        .replace(/\*([^\*\n]+)\*/g, '<em>$1</em>')" 
    HTML .= "        .replace(/\n\n+/g, '<div style=\'height: 4px;\'></div>')" 
    HTML .= "        .replace(/\n/g, '<br>');"
    HTML .= "    document.getElementById('content').innerHTML = html;"
    HTML .= "}"
    HTML .= "</script></head><body><div id='content'></div></body></html>"
    
    WB.Navigate("about:blank")
    while WB.readyState != 4
        Sleep 10
    WB.document.write(HTML)
    WB.document.close()
    
    wbCtrl.Visible := true
    
    Try {
        req := ComObject("Msxml2.ServerXMLHTTP.6.0")
        req.open("POST", ExplainURL, true)
        req.setRequestHeader("Content-Type", "text/plain; charset=utf-8")
        req.send(TextToExplain)
        
        lastLen := 0
        isFirstChunk := true
        
        while (req.readyState != 4) {
            Sleep 40
            Try {
                currentText := req.responseText
                if (StrLen(currentText) > lastLen) {
                    if (isFirstChunk) {
                        TitleText.Value := "DeepSeek 认知解析"
                        TitleText.SetFont("c55AA55")
                        isFirstChunk := false
                    }
                    WB.document.parentWindow.updateContent(currentText)
                    lastLen := StrLen(currentText)
                }
            }
        }
        
        Try {
            currentText := req.responseText
            if (StrLen(currentText) > lastLen) {
                WB.document.parentWindow.updateContent(currentText)
            }
        }
    } Catch as err {
        Try WB.document.parentWindow.updateContent("`n`n[网络或请求错误: " err.Message "]")
    }
}

ShowYellowTip(Msg) {
    TipGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Border", "Tip")
    TipGui.BackColor := "FFFACD" 
    TipGui.SetFont("s11 c333333", "Microsoft YaHei")
    TipGui.Add("Text", "x15 y10", Msg)
    
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mX, &mY)
    TipGui.Show("x" mX+15 " y" mY+15 " NoActivate")
    
    SetTimer () => TipGui.Destroy(), -2000
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    Global g_ExplainGui
    if (g_ExplainGui != "" && hwnd == g_ExplainGui.Hwnd) {
        PostMessage(0xA1, 2, 0, hwnd) 
    }
}

; ==========================================
; === 翻译复原拦截与核心处理逻辑 ===
; ==========================================

#HotIf g_AwaitUndo
$^z::
{
    Global g_AwaitUndo, g_OriginalText, g_IsSelectAll
    g_AwaitUndo := false 
    
    if (g_IsSelectAll) {
        ClipSavedUndo := ClipboardAll()
        A_Clipboard := g_OriginalText
        Sleep 50
        Send "^a"
        Sleep 50
        Send "^v"
        Sleep 150
        A_Clipboard := ClipSavedUndo
        ClipSavedUndo := ""
    } else {
        Send "^{z}"
    }
    ShowTip("已恢复原文！")
}
#HotIf

ProcessTranslation(SelectAll)
{
    Global g_OriginalText, g_IsSelectAll, g_AwaitUndo
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    
    if (SelectAll) {
        Send "^a"
        Sleep 50
    }
    Send "^c"
    
    if !ClipWait(1, 1) { 
        ShowTip("未检测到选中文本！")
        RestoreClipboard(ClipSaved)
        return
    }
    
    OriginalText := A_Clipboard
    if (OriginalText == "" || RegExMatch(OriginalText, "^\s*$")) {
        ShowTip("文本为空！")
        RestoreClipboard(ClipSaved)
        return
    }

    ShowTip("正在呼叫 DeepSeek 翻译中...")
    TranslatedText := RequestTranslation(OriginalText)
    
    if (TranslatedText == "ERROR") {
        ShowTip("翻译失败，请检查后台 Python 服务或网络。")
        RestoreClipboard(ClipSaved)
        return
    }
    
    A_Clipboard := TranslatedText
    Sleep 50 
    Send "^v"
    Sleep 150 
    
    RestoreClipboard(ClipSaved)
    ShowTip("翻译完成！")
    
    g_OriginalText := OriginalText
    g_IsSelectAll := SelectAll
    g_AwaitUndo := true
}

RequestTranslation(TextToTranslate)
{
    Global ServerURL
    Try {
        req := ComObject("Msxml2.XMLHTTP")
        req.open("POST", ServerURL, true)
        req.setRequestHeader("Content-Type", "text/plain; charset=utf-8")
        req.send(TextToTranslate)
        
        while req.readyState != 4
            Sleep 50
            
        if (req.status == 200) {
            return req.responseText
        }
    } Catch {
        return "ERROR"
    }
    return "ERROR"
}

ShowTip(Msg)
{
    ToolTip Msg
    SetTimer () => ToolTip(), -2500 
}

RestoreClipboard(ClipSaved)
{
    A_Clipboard := ClipSaved
    ClipSaved := "" 
}
