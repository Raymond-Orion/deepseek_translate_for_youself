import json
import os
import sys
import ctypes

# 强制依赖检测系统 (很多时候 pip install PyQt6 会漏掉 WebEngine)
try:
    from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                                 QPushButton, QLabel, QDialog, QLineEdit, QFileDialog, QGraphicsDropShadowEffect)
    from PyQt6.QtCore import Qt, QThread, pyqtSignal, QPoint
    from PyQt6.QtGui import QPainter, QPixmap, QColor, QIcon, QPainterPath
    from PyQt6.QtWebEngineWidgets import QWebEngineView
except ImportError as e:
    ctypes.windll.user32.MessageBoxW(0, f"依赖缺失或损坏，UI界面启动失败！\n\n报错信息：{str(e)}\n\n请在 CMD 中执行：\npip install PyQt6 PyQt6-WebEngine", "致命错误", 0x10)
    sys.exit(1)

try:
    from openai import OpenAI
except ImportError:
    ctypes.windll.user32.MessageBoxW(0, "未安装 OpenAI 官方库！\n请执行: pip install openai", "致命错误", 0x10)
    sys.exit(1)

CONFIG_FILE = "config.json"

def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {}
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_config(config):
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=4)

# ================= 异步流式请求线程 =================
class DeepSeekStreamWorker(QThread):
    chunk_received = pyqtSignal(str)
    finished = pyqtSignal()
    error = pyqtSignal(str)

    def __init__(self, text, config):
        super().__init__()
        self.text = text
        self.config = config

    def run(self):
        api_key = self.config.get("api_key", "")
        if not api_key:
            self.error.emit("错误：请先点击右上角设置配置 API Key")
            return
            
        client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com")
        try:
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": self.config.get("prompt_cognitive", "")},
                    {"role": "user", "content": self.text}
                ],
                stream=True
            )
            for chunk in response:
                if chunk.choices[0].delta.content:
                    self.chunk_received.emit(chunk.choices[0].delta.content)
            self.finished.emit()
        except Exception as e:
            self.error.emit(f"请求失败: {str(e)}")

# ================= 设置面板 Dialog =================
class SettingsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("设置")
        self.setFixedSize(400, 200)
        self.config = load_config()
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)

        layout.addWidget(QLabel("DeepSeek API Key:"))
        self.api_input = QLineEdit(self.config.get("api_key", ""))
        self.api_input.setEchoMode(QLineEdit.EchoMode.Password)
        layout.addWidget(self.api_input)

        bg_layout = QHBoxLayout()
        self.bg_label = QLabel(self.config.get("bg_image", "未设置背景"))
        self.bg_btn = QPushButton("选择背景图片")
        self.bg_btn.clicked.connect(self.choose_bg)
        bg_layout.addWidget(self.bg_label)
        bg_layout.addWidget(self.bg_btn)
        layout.addLayout(bg_layout)

        save_btn = QPushButton("保存并应用")
        save_btn.clicked.connect(self.save_settings)
        layout.addWidget(save_btn)

    def choose_bg(self):
        file_name, _ = QFileDialog.getOpenFileName(self, "选择背景图片", "", "Images (*.png *.jpg *.jpeg)")
        if file_name:
            self.bg_label.setText(file_name)

    def save_settings(self):
        self.config["api_key"] = self.api_input.text()
        bg_text = self.bg_label.text()
        if bg_text != "未设置背景":
            self.config["bg_image"] = bg_text
        save_config(self.config)
        self.accept()

# ================= 核心主窗口 =================
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = load_config()
        self.init_ui()
        self.dragPos = QPoint()
        self.worker = None

        self.html_template = """
        <!DOCTYPE html>
        <html>
        <head>
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.2.0/github-markdown-dark.min.css">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; 
                       padding: 15px; background: transparent; color: #e0e0e0; }
                .markdown-body { background: transparent !important; color: #e0e0e0 !important; }
                ::-webkit-scrollbar { width: 8px; }
                ::-webkit-scrollbar-track { background: transparent; }
                ::-webkit-scrollbar-thumb { background: #555; border-radius: 4px; }
            </style>
        </head>
        <body class="markdown-body">
            <div id="content">等待输入...</div>
            <script>
                let fullText = "";
                function resetText() { fullText = ""; document.getElementById('content').innerHTML = "思考中..."; }
                function appendText(chunk) {
                    fullText += chunk;
                    document.getElementById('content').innerHTML = marked.parse(fullText);
                    window.scrollTo(0, document.body.scrollHeight);
                }
                function setError(msg) { document.getElementById('content').innerHTML = `<span style="color:#ff6b6b">${msg}</span>`; }
            </script>
        </body>
        </html>
        """
        self.web_view.setHtml(self.html_template)

    def init_ui(self):
        self.resize(550, 650)
        # 加入 WindowStaysOnTopHint，防止弹窗被 IDE 遮挡
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

        central_widget = QWidget(self)
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)

        self.container = QWidget()
        self.container.setObjectName("MainContainer")
        
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(15)
        shadow.setColor(QColor(0, 0, 0, 180))
        shadow.setOffset(0, 0)
        self.container.setGraphicsEffect(shadow)

        layout = QVBoxLayout(self.container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        header = QWidget()
        header.setFixedHeight(40)
        header.setStyleSheet("background-color: rgba(30, 30, 30, 150); border-top-left-radius: 12px; border-top-right-radius: 12px;")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(15, 0, 10, 0)
        
        title = QLabel("DeepSeek 认知解析")
        title.setStyleSheet("color: white; font-weight: bold;")
        
        settings_btn = QPushButton("⚙")
        settings_btn.setFixedSize(28, 28)
        settings_btn.setStyleSheet("QPushButton { background: transparent; color: white; font-size: 16px; border: none; } QPushButton:hover { color: #aaaaaa; }")
        settings_btn.clicked.connect(self.open_settings)

        close_btn = QPushButton("✕")
        close_btn.setFixedSize(28, 28)
        close_btn.setStyleSheet("QPushButton { background: transparent; color: white; font-size: 14px; border: none; } QPushButton:hover { color: #ff4757; }")
        close_btn.clicked.connect(self.hide)

        header_layout.addWidget(title)
        header_layout.addStretch()
        header_layout.addWidget(settings_btn)
        header_layout.addWidget(close_btn)
        layout.addWidget(header)

        self.web_view = QWebEngineView()
        # 严谨处理：传入 QColor 透明对象，防止部分系统 TypeError
        self.web_view.page().setBackgroundColor(QColor(0, 0, 0, 0))
        layout.addWidget(self.web_view)

        main_layout.addWidget(self.container)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        path = QPainterPath()
        path.addRoundedRect(10, 10, self.width()-20, self.height()-20, 12, 12)
        painter.setClipPath(path)

        bg_path = self.config.get("bg_image", "")
        if os.path.exists(bg_path):
            pixmap = QPixmap(bg_path).scaled(self.size(), Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation)
            painter.drawPixmap(0, 0, pixmap)
            painter.fillRect(self.rect(), QColor(20, 20, 20, 210))
        else:
            painter.fillRect(self.rect(), QColor(25, 25, 25, 240))

    def open_settings(self):
        dlg = SettingsDialog(self)
        if dlg.exec():
            self.config = load_config()
            self.update()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and event.pos().y() < 50:
            self.dragPos = event.globalPosition().toPoint()

    def mouseMoveEvent(self, event):
        if not self.dragPos.isNull():
            delta = event.globalPosition().toPoint() - self.dragPos
            self.move(self.pos() + delta)
            self.dragPos = event.globalPosition().toPoint()

    def mouseReleaseEvent(self, event):
        self.dragPos = QPoint()

    def start_analysis(self, text):
        print("💻 [UI主线程] 正在弹出解析窗口...")
        self.config = load_config()
        self.web_view.page().runJavaScript("resetText();")
        
        self.show()
        self.raise_()
        self.activateWindow()

        self.worker = DeepSeekStreamWorker(text, self.config)
        self.worker.chunk_received.connect(self.on_chunk)
        self.worker.error.connect(self.on_error)
        self.worker.start()

    def on_chunk(self, text):
        safe_text = json.dumps(text)
        self.web_view.page().runJavaScript(f"appendText({safe_text});")

    def on_error(self, msg):
        safe_msg = json.dumps(msg)
        self.web_view.page().runJavaScript(f"setError({safe_msg});")