#Requires AutoHotkey v2.0
#SingleInstance Force

ServerURL := "http://127.0.0.1:8989/translate"

; ========== 快捷键定义 ==========

; Ctrl + Shift + 6: 翻译当前【已选中】的文字
^+6::
{
    ProcessTranslation(false)
}

; Ctrl + Shift + 7: 翻译【当前输入框全部】文字 (自动全选)
^+7::
{
    ProcessTranslation(true)
}

; ========== 核心处理逻辑 ==========

ProcessTranslation(SelectAll)
{
    ; 1. 备份原剪贴板，防止污染历史记录
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    
    ; 2. 抓取文本
    if (SelectAll) {
        Send "^{a}"
        Sleep 50
    }
    Send "^{c}"
    
    ; 等待剪贴板包含文本，最多等1秒
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

    ; 3. 提示并向 Python 服务发送请求
    ShowTip("正在呼叫 DeepSeek 翻译中...")
    
    TranslatedText := RequestTranslation(OriginalText)
    
    if (TranslatedText == "ERROR") {
        ShowTip("翻译失败，请检查后台 Python 服务或网络。")
        RestoreClipboard(ClipSaved)
        return
    }
    
    ; 4. 粘贴替换并恢复原剪贴板
    A_Clipboard := TranslatedText
    Sleep 50  ; 给系统剪贴板 50ms 缓冲时间
    Send "^{v}"
    Sleep 150 ; 稍作等待，确保系统完成真实的粘贴动作后再恢复剪贴板
    
    RestoreClipboard(ClipSaved)
    ShowTip("翻译完成！")
}

RequestTranslation(TextToTranslate)
{
    global ServerURL
    Try {
        req := ComObject("Msxml2.XMLHTTP")
        req.open("POST", ServerURL, true)
        ; 使用 text/plain，彻底避开 JSON 中特殊字符转义的坑
        req.setRequestHeader("Content-Type", "text/plain; charset=utf-8")
        req.send(TextToTranslate)
        
        ; 循环等待异步请求返回
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
    ; -2500 代表 2.5 秒后自动执行清除 ToolTip 的操作，且不阻塞当前进程
    SetTimer () => ToolTip(), -2500 
}

RestoreClipboard(ClipSaved)
{
    A_Clipboard := ClipSaved
    ClipSaved := "" ; 释放内存
}