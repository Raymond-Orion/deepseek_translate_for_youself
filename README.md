# DeepSeek 智能翻译与认知解析助手 - 使用文档

> 基于 Python (Flask) + AutoHotkey (AHK v2) + PyQt6 的桌面端划词 AI 增强与认知拆解系统

---

## 📌 1. 项目概述 (Overview)

本项目是一个专为开发者、技术研究人员及外语学习者打造的本地桌面 AI 辅助工具。它无缝整合了全局划词悬浮窗、流式认知拆解、静默翻译替换以及全自动环境引导，让你可以随时随地对屏幕上的任意文本进行深度理解与专业互译。

### 核心亮点

* **零感静默启动**：通过 `Launcher.vbs` 实现无黑框、防报错的完全后台静默加载。
* **高清划词悬浮窗**：基于 AutoHotkey v2 与 GDI+ 亚像素渲染引擎，完美支持多屏 DPI 缩放与透明毛玻璃特效。
* **流式认知解析**：采用 PyQt6 + QWebEngineView + Marked.js，实时呈现四维认知语言学拆解。
* **便捷替换与撤销**：支持选中替换、全文替换以及 30 秒内的 `Ctrl + Z` 智能撤销恢复。

---

## 🛠️ 2. 项目目录结构与核心文件

| 文件名 | 类型 | 核心功能说明 |
| --- | --- | --- |
| `Launcher.vbs` | VBS 脚本 | Foolproof 静默启动器，设置 UTF-8 编码并丢弃冗余输出，后台异步拉起 Python 与 AHK。 |
| `install_env.bat` | 批处理脚本 | 一键安装所有依赖项（包含 85 个核心 Python 库如 PyQt6, OpenAI, Flask 等）。 |
| `main.py` | Python 脚本 | 本地 Flask 后端（监听端口 15051）与 PyQt6 主线程总线，处理 API 转发与 UI 唤醒。 |
| `main.ahk` | AHK v2 脚本 | 划词监听、防误触引擎、GDI+ 高DPI悬浮图标渲染与快捷键响应。 |
| `ui_window.py` | Python 模块 | PyQt6 框架下带有阴影、毛玻璃背景和 Markdown 渲染的流式解析悬浮窗口。 |
| `config.json` | JSON 配置 | 存储 DeepSeek API Key、背景图片路径及 Prompt 模板。 |

---

## 🚀 3. 安装与部署指南 (Installation & Setup)

### 环境要求

* **操作系统**：Windows 10 / 11 (支持多屏高 DPI)
* **运行环境**：Python 3.10+ 及 AutoHotkey v2.0+

### 第一步：安装依赖库

在项目根目录下双击运行 `install_env.bat`，脚本会自动升级核心工具并安装所有必需的第三方库（共 85 个预置包，确保环境完整无缺）。

```bash
# 手动安装核心依赖（若需要）
pip install PyQt6 PyQt6-WebEngine openai flask requests pywin32

```

### 第二步：配置 API Key 与壁纸

首次运行会在同级目录下自动生成 `config.json`。请打开并填入你的 DeepSeek API Key：

```json
{
    "api_key": "你的_DeepSeek_API_Key",
    "bg_image": "C:/path/to/your/bg.jpg",
    "prompt_translate": "...",
    "prompt_cognitive": "..."
}

```

---

## ⌨️ 4. 快捷键与使用操作指南

| 操作方式 | 快捷键 / 触发条件 | 功能效果 |
| --- | --- | --- |
| **划词悬浮图标** | 鼠标左键拖拽划词 (距离 > 10px) | 在选中文本右下方自动弹出 DeepSeek 蓝鲸悬浮图标，点击即可触发认知解析。 |
| **认知深度解析** | `Ctrl + Shift + 9` | 直接对当前选中的文本进行四维认知语言学拆解（流式输出至美观的毛玻璃解析窗口）。 |
| **选中翻译替换** | `Ctrl + Shift + 8` | 将选中的外文/中文精准互译，并直接原地替换选中文本。 |
| **全文翻译替换** | `Ctrl + Shift + 7` | 全选当前文档/文本框内容 (Ctrl+A)，翻译后整体替换。 |
| **智能撤销保护** | `Ctrl + Z` (替换后 30 秒内) | 自动挂载撤销监听，按 `Ctrl+Z` 可一键恢复被替换前的原始内容。 |

---

## 💡 5. 常见问题与排障指南 (Troubleshooting)

> **❌ 问题一：控制台出现 UnicodeEncodeError (GBK 编码报错)**
> Python 默认在 Windows GBK 控制台打印 Emoji 字符（如 `⏳`、`📡`）时会崩溃。
> **解决方案**：直接使用 `Launcher.vbs` 启动，它会强制注入 `PYTHONIOENCODING=utf-8` 并将输出丢弃到系统黑洞，彻底杜绝此问题。

> **❌ 问题二：端口 15051 被占用 (OSError: [Errno 48] Address already in use)**
> **解决方案**：打开任务管理器 (Task Manager)，找到残留的 `python.exe` 进程并结束任务，然后重新启动即可。

> **💡 小贴士：如何一键开机自启？**
> 右键点击 `Launcher.vbs` ➔ **发送到** ➔ **桌面快捷方式**，然后按 `Win + R` 输入 `shell:startup`，将快捷方式粘贴到启动文件夹中，即可实现开机静默后台运行！
