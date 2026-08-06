import sys
import json
import os
import logging
import httpx
import tempfile
from flask import Flask, request, jsonify
from openai import OpenAI

# 强制输出 utf-8 编码，防止 cmd 报错崩溃
sys.stdout.reconfigure(encoding='utf-8')

CONFIG_FILE = "config.json"
app_flask = Flask(__name__)

def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {}
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

# 【核心修复】跨进程气泡提示功能
def show_reload_bubble():
    ahk_code = '''#Requires AutoHotkey v2.0
ToolTip("✅ Python 后端服务已重新加载")
Sleep(2000)
ExitApp()
'''
    try:
        # 在系统临时目录生成一个阅后即焚的 AHK 脚本
        bubble_path = os.path.join(tempfile.gettempdir(), "python_reload_bubble.ahk")
        with open(bubble_path, "w", encoding="utf-8-sig") as f:
            f.write(ahk_code)

        # 完美修复：使用 Windows 原生 API 直接启动文件，彻底避免 cmd.exe 的解析 bug
        os.startfile(bubble_path)
    except Exception:
        pass

@app_flask.route('/translate', methods=['POST'])
def translate():
    try:
        data = request.json
        text = data.get('text', '')

        config = load_config()
        api_key = config.get("api_key", "")
        target_model = config.get("model_translate", "deepseek-chat")

        if not api_key:
            return jsonify({"error": "API Key 未设置"}), 400

        custom_http_client = httpx.Client(proxy=None, trust_env=False)

        client = OpenAI(
            api_key=api_key, 
            base_url="https://api.deepseek.com",
            http_client=custom_http_client
        )

        response = client.chat.completions.create(
            model=target_model,
            messages=[
                {"role": "system", "content": config.get("prompt_translate", "")},
                {"role": "user", "content": text}
            ],
            stream=False,
            temperature=0,
            max_tokens=2048
        )
        result = response.choices[0].message.content
        return jsonify({"result": result})

    except Exception as e:
        return jsonify({"error": f"Python Backend Error: {str(e)}"}), 500

if __name__ == '__main__':
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)

    # 利用环境变量判断当前是“主进程”还是“热重载后的子进程”
    if os.environ.get("WERKZEUG_RUN_MAIN") == "true":
        print("🔄 侦测到代码保存 (Ctrl+S)，Python 服务已自动热重载！")
        show_reload_bubble() # 触发气泡
    else:
        print("⏳ 翻译后台服务已启动 (端口 15051)... [已开启保存自动重载]")

    try:
        app_flask.run(port=15051, debug=False, use_reloader=True, extra_files=[CONFIG_FILE])
    except OSError as e:
        print(f"❌ 端口 15051 被占用，请双击 ccc_killer.bat 杀死残留进程！\n详情: {e}")
