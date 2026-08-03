# DeepSeek Windows全局输入框翻译与便捷查词助手使用文档

本系统是一套基于 **FastAPI (Python)** 后端微服务与 **AutoHotkey v2 (AHK)** 前端客户端的高效划词翻译与认知词汇解析工具。系统深度对接 **DeepSeek API**，不仅支持快速选词/全选翻译替换，还创新性地结合认知语言学，对单词进行物理画面与隐喻演变的流式深度解析。

---

## 一、 系统架构与核心功能

系统由以下两部分协同构成：

1. **后端微服务 (`server.py`)**：


* 基于 FastAPI 异步框架。


* `/translate` 接口：提供高质量英汉/汉英互译，适应学术、高级期刊与 IT 技术专业语境。


* `/explain` 接口：提供 **流式响应 (StreamingResponse)**，输出基于认知语言学的单词深度拆解。




2. **前端客户端 (`client.ahk`)**：


* 监听全局快捷键，自动捕获剪贴板文本。


* 内置 ActiveX HTML/CSS 渲染窗口，支持实时 Markdown 表格与流式文本渲染。


* 具备快捷键撤销恢复（Ctrl+Z 还原原文）机制。





---

## 二、 快捷键指南

| 快捷键 | 功能 | 说明与效果 |
| --- | --- | --- |
| Ctrl + Shift + 8<br> | **选中文本翻译替换**<br> | 选中文本后按下，自动呼叫翻译服务并在原地粘贴替换为翻译结果。

 |
| Ctrl + Shift + 7<br> | **全选并翻译替换**<br> | 自动全选当前输入框文本（Ctrl+A），翻译后整段替换。

 |
| Ctrl + Shift + 9<br> | **深度认知解析 (窗口展示)**<br> | 选中文本/单词后按下，弹出深色居中窗口，以流式动画展示认知解析。

 |
| Ctrl + Z<br> | **翻译复原 (撤销)**<br> | 在执行翻译替换后，若不满意可按 Ctrl+Z 完美还原原替换文本。

 |

---

## 三、 深度认知解析（Explain）拆解维度

使用 Ctrl+Shift+9 触发认知解析时，系统会将单词拆解为以下 4 个维度：

1. **核心物理画面/动作 (The Physical Core / Physical Motion)**

* 用最具画面感的语言，还原词汇最原始的物理动作（如：拉缰绳、盖盖子）及词根词缀视觉含义。




2. **隐喻与抽象发散 (Metaphorical Extension)**

* 解释作者如何将物理动作引申至抽象场景（如：从“拉缰绳”延伸至“控制通胀/约束情绪”）及逻辑联系。




3. **原生精准语境与写作示范 (Context & Precision)**

* 提供 2 个高级地道英文例句（涵盖社科、政经或文学），并精准辨析与中文近义词的微妙画面区别。




4. **一句话记忆锚点 (Memory Anchor)**

* 概括 **【物理画面】 ➔ 【抽象隐喻】**，帮助建立形-画面-义直连。





---

## 四、 快速部署与使用步骤

### 1. 安装环境依赖

在使用前，请确保安装了 **Python 3.9+** 与 **AutoHotkey v2**。
在命令行运行以下命令安装 Python 依赖项：

```bash
pip install fastapi uvicorn openai python-dotenv

```

### 2. 配置文件 (`.env`)

在项目根目录创建或修改 `.env` 文件，填入你的 DeepSeek API Key：

```env
DEEPSEEK_API_KEY=""
DEEPSEEK_BASE_URL="https://api.deepseek.com/v1"
SERVER_PORT=8989

```

### 3. 系统启动

* **推荐（一键后台无窗口启动）：**
双击运行 `start.vbs` 文件，系统将自动隐藏CMD黑窗口并在后台同时拉起 Python 服务与 AHK 客户端。


* **手动启动：**
1. 运行 API 服务：`python server.py`

2. 运行 AHK 脚本：双击 `client.ahk`
