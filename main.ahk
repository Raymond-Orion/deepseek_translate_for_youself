#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
SendMode "Input"

; ================= 全局变量 =================
global startX := 0
global startY := 0
global iconGui := ""
global originalText := ""
global selectedText := ""

; 初始化隐式全局按键监听 (用于打断/隐藏悬浮图标)
global keyHook := InputHook("V")
keyHook.KeyOpt("{All}", "V")
keyHook.OnKeyDown := (ih, vk, sc) => HideIcon()

; ================= 1. 划词与防误触引擎 =================
~LButton::
{
    global startX, startY, iconGui
    MouseGetPos(&startX, &startY, &hoverWin)
    
    ; 鼠标悬浮在图标窗口上时不销毁，确保点击能正常响应
    if (iconGui and hoverWin == iconGui.Hwnd)
        return

    HideIcon() ; 点击其他位置销毁浮标
}

~LButton up::
{
    global startX, startY, selectedText
    MouseGetPos(&endX, &endY)

    ; 防误触 1: 修饰键屏蔽
    if GetKeyState("Ctrl", "P") or GetKeyState("Alt", "P") or GetKeyState("LWin", "P") or GetKeyState("RWin", "P") or GetKeyState("Shift", "P")
        return

    distance := Sqrt((endX - startX)**2 + (endY - startY)**2)

    ; 防误触 2 & 3: 拖拽距离与光标模式严格校验
    if (distance < 10)
        return
    if (A_Cursor == "IBeam" and distance < 15)
        return

    ; 静默提取文本
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^{c}")
    if !ClipWait(0.2)
    {
        A_Clipboard := ClipSaved
        return
    }
    
    text := A_Clipboard
    A_Clipboard := ClipSaved ; 恢复剪贴板

    ; 防误触 4: 字符过滤
    if text == "" or RegexMatch(text, "^\s+$")
        return
    if StrLen(Trim(text)) == 1 and RegexMatch(Trim(text), "^[[:punct:]]$")
        return

    selectedText := text
    ShowIcon(endX, endY)
}

; ================= 2. GDI+ 多屏 DPI 高清悬浮图标 =================
GetImageDimensions(imgPath, &imgW, &imgH)
{
    static pToken := 0
    if !pToken
    {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken, "Ptr", si, "Ptr", 0)
    }
    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", imgPath, "UPtr*", &pBitmap := 0)
    if !pBitmap
        return false
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &imgW := 0)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &imgH := 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    return true
}

ShowIcon(x, y)
{
    global iconGui, keyHook, selectedText
    HideIcon()

    imgPath := A_ScriptDir . "\deepseek.png"
    if !FileExist(imgPath)
    {
        MsgBox("未找到 deepseek.png，请确保图片与脚本在同一目录下！")
        return
    }

    ; 动态读取图片原始宽高，自适应计算比例[cite: 1]
    imgW := 0, imgH := 0
    if !GetImageDimensions(imgPath, &imgW, &imgH) or imgW == 0 or imgH == 0
    {
        imgW := 32, imgH := 32
    }

    ; 获取当前显示器 DPI 比例
    dpi := GetDpiForMonitor(x, y)
    scale := dpi / 96.0

    ; 基础高度设为 32，宽度根据原图比例自动计算
    baseH := 32
    baseW := Round(baseH * (imgW / imgH))

    w := Round(baseW * scale)
    h := Round(baseH * scale)

    ; 创建 WS_EX_LAYERED (0x80000) 32位透明分层窗口[cite: 1]
    iconGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x80000")
    iconGui.Show("NA x" . (x + 15) . " y" . (y + 10) . " w" . w . " h" . h)

    ; 使用 GDI+ 执行双三次重采样高清绘制[cite: 1]
    DrawHighDpiIcon(iconGui.Hwnd, imgPath, w, h)

    ; 绑定左键点击消息 (WM_LBUTTONDOWN)[cite: 1]
    OnMessage(0x0201, OnIconClick)

    SetTimer(HideIcon, -2000)
    keyHook.Start()
}

HideIcon()
{
    global iconGui, keyHook
    SetTimer(HideIcon, 0)
    if IsSet(keyHook) and keyHook.InProgress
        keyHook.Stop()
    
    if IsSet(iconGui) and iconGui
    {
        OnMessage(0x0201, OnIconClick, 0) ; 取消绑定[cite: 1]
        iconGui.Destroy()
        iconGui := ""
    }
}

OnIconClick(wParam, lParam, msg, hwnd)
{
    global iconGui
    if (iconGui and hwnd == iconGui.Hwnd)
    {
        TriggerStreamAnalysis()
    }
}

TriggerStreamAnalysis()
{
    global selectedText
    HideIcon()
    SendRequest("/analyze", selectedText)
}

; GDI+ 亚像素高清渲染引擎 (已实现纯透明背景)
DrawHighDpiIcon(hwnd, imgPath, width, height)
{
    static pToken := 0
    if !pToken
    {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken, "Ptr", si, "Ptr", 0)
    }

    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", imgPath, "UPtr*", &pBitmap := 0)
    if !pBitmap
        return

    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", width, "Int", -height, "UShort", 1, "UShort", 32, bi)
    hbm := DllCall("CreateDIBSection", "Ptr", hdcScreen, "Ptr", bi, "UInt", 0, "UPtr*", &pBits := 0, "Ptr", 0, "UInt", 0, "Ptr")
    obm := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")

    DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "UPtr*", &pGraphics := 0)
    
    ; 抗锯齿与高质量重采样[cite: 1]
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pGraphics, "Int", 7) ; HighQualityBicubic
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)     ; AntiAlias
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", pGraphics, "Int", 2)    ; HighQuality

    ; 不填充任何底色矩形，保持窗口背景完全透明
    
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &imgW := 0)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &imgH := 0)
    
    ; 边距设为 0，让图片完整充满整个透明窗口
    pad := 0
    DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", pGraphics, "Ptr", pBitmap
        , "Float", pad, "Float", pad, "Float", width - (pad*2), "Float", height - (pad*2)
        , "Float", 0, "Float", 0, "Float", imgW, "Float", imgH
        , "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)

    ; 更新分层透明窗口[cite: 1]
    ptDst := Buffer(8), ptSrc := Buffer(8, 0)
    size := Buffer(8)
    NumPut("Int", width, "Int", height, size)
    blend := Buffer(4)
    NumPut("UChar", 0, "UChar", 0, "UChar", 255, "UChar", 1, blend)

    ; Alpha 预乘与全透明像素清零（防止透明边缘发黑）
    p := pBits
    loop width * height
    {
        color := NumGet(p, "UInt")
        a := (color >> 24) & 0xFF
        if (a == 0)
        {
            NumPut("UInt", 0, p)
        }
        else if (a < 255)
        {
            r := (((color >> 16) & 0xFF) * a + 127) // 255
            g := (((color >> 8) & 0xFF) * a + 127) // 255
            b := ((color & 0xFF) * a + 127) // 255
            NumPut("UInt", (a << 24) | (r << 16) | (g << 8) | b, p)
        }
        p += 4
    }

    DllCall("UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcScreen, "Ptr", 0, "Ptr", size
        , "Ptr", hdcMem, "Ptr", ptSrc, "UInt", 0, "Ptr", blend, "UInt", 2)

    ; 清理资源[cite: 1]
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", obm)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
}

GetDpiForMonitor(x, y)
{
    pt := Buffer(8)
    NumPut("Int", x, "Int", y, pt)
    hMonitor := DllCall("MonitorFromPoint", "Int64", NumGet(pt, 0, "Int64"), "UInt", 2, "Ptr")
    dpiX := 96, dpiY := 96
    try {
        DllCall("Shcore\GetDpiForMonitor", "Ptr", hMonitor, "Int", 0, "UInt*", &dpiX, "UInt*", &dpiY)
    }
    return dpiX
}

; ================= 3. 核心功能快捷键 =================
^+9:: ; Ctrl+Shift+9: 认知解析[cite: 1]
{
    HideIcon()
    text := GetSelectedTextSafely()
    if (text != "")
        SendRequest("/analyze", text)
}

^+8:: ; Ctrl+Shift+8: 选中替换[cite: 1]
{
    HideIcon()
    text := GetSelectedTextSafely()
    if (text != "")
        DoTranslateAndReplace(text)
}

^+7:: ; Ctrl+Shift+7: 全文替换[cite: 1]
{
    HideIcon()
    Send("^{a}")
    Sleep(50)
    text := GetSelectedTextSafely()
    if (text != "")
        DoTranslateAndReplace(text)
}

; ================= 4. 通信与撤销支持 =================
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
        http.Open("POST", "http://127.0.0.1:15051" . endpoint, true)
        http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")
        
        safeText := StrReplace(text, "\", "\\")
        safeText := StrReplace(safeText, "`"", "\`"")
        safeText := StrReplace(safeText, "`n", "\n")
        safeText := StrReplace(safeText, "`r", "\r")
        safeText := StrReplace(safeText, "`t", "\t")
        
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

EnableUndoHook()
{
    Hotkey("^z", UndoAction, "On")
    SetTimer(DisableUndoHook, -30000)
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
