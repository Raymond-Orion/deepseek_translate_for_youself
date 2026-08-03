import sys
import json
import os
import threading
from flask import Flask, request, jsonify

# 引入报错检测
try:
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtCore import pyqtSignal, QObject
    from openai import OpenAI
    from ui_window import MainWindow
except ImportError as e:
    import ctypes
    ctypes.windll.user32.MessageBoxW(0, f"主程序导入失败！缺少依赖：\n{str(e)}", "致命错误", 0x10)
    sys.exit(1)

CONFIG_FILE = "config.json"
DEFAULT_CONFIG = {
    "api_key": "",
    "bg_image": "",
    "prompt_translate": "你是一个资深IT与网络专家。请精确翻译以下文本...",
    "prompt_cognitive": "你是一个认知语言学专家。请对以下内容进行四维认知拆解..."
}

class SignalBus(QObject):
    show_analyze_window = pyqtSignal(str)

bus = None
app_flask = Flask(__name__)

def load_config():
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(DEFAULT_CONFIG, f, ensure_ascii=False, indent=4)
        return DEFAULT_CONFIG
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

@app_flask.route('/translate', methods=['POST'])
def translate():
    data = request.json
    text = data.get('text', '')
    print(f"📡 [Flask] 收到静默翻译请求: {text[:15]}...")
    
    config = load_config()
    api_key = config.get("api_key", "")
    if not api_key:
        print("❌ [Flask] API Key 未设置！")
        return jsonify({"error": "API Key not set"}), 400

    client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com")
    try:
        response = client.chat.completions.create(
            model="deepseek-v4-flash",
            messages=[
                {"role": "system", "content": config.get("prompt_translate", "")},
                {"role": "user", "content": text}
            ],
            stream=False
        )
        result = response.choices[0].message.content
        print("✅ [Flask] 翻译完成，已返回给 AHK")
        return jsonify({"result": result})
    except Exception as e:
        print(f"❌ [Flask] API 请求失败: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app_flask.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    text = data.get('text', '')
    print(f"📡 [Flask] 收到认知拆解请求: {text[:15]}...")
    
    if bus:
        bus.show_analyze_window.emit(text)
        print("✅ [Flask] 唤醒信号已成功发送至 UI 主线程")
    else:
        print("❌ [Flask] 严重错误：SignalBus 通信总线丢失")
    return jsonify({"status": "ok"})

def run_flask():
    print("⏳ 正在后台启动 Flask 监听 (端口 15051)...")
    try:
        # 关闭 werkzeug 的默认输出，保持控制台干净
        import logging
        log = logging.getLogger('werkzeug')
        log.setLevel(logging.ERROR)
        app_flask.run(port=15051, debug=False, use_reloader=False)
    except OSError as e:
        print(f"\n❌ [严重错误] 端口 15051 被占用！请在任务管理器杀死残留的 python.exe！\n详情: {e}")

if __name__ == '__main__':
    print("============== 系统启动检查 ==============")
    print("⏳ 1. 正在初始化 PyQt6 UI 引擎...")
    app = QApplication(sys.argv)
    
    print("⏳ 2. 正在初始化跨线程通信总线...")
    bus = SignalBus()
    
    print("⏳ 3. 正在启动网络探针...")
    server_thread = threading.Thread(target=run_flask, daemon=True)
    server_thread.start()
    
    print("⏳ 4. 正在预渲染毛玻璃界面 (隐形待命)...")
    main_window = MainWindow()
    bus.show_analyze_window.connect(main_window.start_analysis)
    
    print("✅ 系统全部启动成功！程序已进入后台潜伏。")
    print("👉 尝试选中一段文字，然后按下 Ctrl + Shift + 9 吧！")
    print("==========================================")
    
    sys.exit(app.exec())