#Requires AutoHotkey v2.0
#SingleInstance Force

ServerURL := "http://127.0.0.1:8989/translate"
Global ExplainURL := "http://127.0.0.1:8989/explain"
Global g_ExplainGui := ""

; ==========================================
; === 全局状态记录，用于 Ctrl+Z 完美复原 ===
; ==========================================
Global g_OriginalText := ""
Global g_IsSelectAll := false
Global g_AwaitUndo := false

~*LButton::CancelUndo()
~*RButton::CancelUndo()

CancelUndo() {
    global g_AwaitUndo
    g_AwaitUndo := false
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

; Ctrl + Shift + 9: 屏幕居中、支持 Markdown 表格与流式解析
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
    global ExplainURL, g_ExplainGui
    
    ; 1. 抓取文本
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    
    if !ClipWait(0.5, 1) { 
        ShowYellowTip("未检测到文本")
        RestoreClipboard(ClipSaved)
        return
    }
    
    TextToExplain := A_Clipboard
    if (TextToExplain == "") {
        ShowYellowTip("未检测到文本")
        RestoreClipboard(ClipSaved)
        return
    }
    
    ; 2. 准备 深色GUI
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
    
    ; 加入隐藏的 Web 渲染引擎，用于解析 Markdown 和表格
    wbCtrl := g_ExplainGui.Add("ActiveX", "x10 y35 w780 h455 Hidden", "Shell.Explorer")
    WB := wbCtrl.Value
    
    g_ExplainGui.OnEvent("Escape", (*) => g_ExplainGui.Destroy())
    OnMessage(0x0201, WM_LBUTTONDOWN)
    
    ; 3. 屏幕居中展示
    g_ExplainGui.Show("w800 h500 NoActivate Center")
    
    ; 注入定制的 HTML/CSS 和实时解析脚本
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
    
    ; 优化表格前后的空白行裁剪逻辑
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
    
    ; 4. 发起 HTTP 流式请求
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
    
    RestoreClipboard(ClipSaved)
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
    global g_ExplainGui
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
    global g_AwaitUndo, g_OriginalText, g_IsSelectAll
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
    global g_OriginalText, g_IsSelectAll, g_AwaitUndo
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
    if (OriginalText == "") {
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
    global ServerURL
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