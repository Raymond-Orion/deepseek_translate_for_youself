import sys
import json
import os
import logging
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

@app_flask.route('/translate', methods=['POST'])
def translate():
    data = request.json
    text = data.get('text', '')
    
    config = load_config()
    api_key = config.get("api_key", "")
    target_model = config.get("model_translate", "deepseek-chat")
    
    if not api_key:
        return jsonify({"error": "API Key 未设置"}), 400

    client = OpenAI(api_key=api_key, base_url="[https://api.deepseek.com](https://api.deepseek.com)")
    try:
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
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # 关闭 Flask 的默认终端刷屏输出，保持静默
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)
    
    print("⏳ 翻译后台服务已启动 (端口 15051)...")
    try:
        app_flask.run(port=15051, debug=False, use_reloader=False)
    except OSError as e:
        print(f"❌ 端口 15051 被占用，请杀死残留进程！\\n详情: {e}")
