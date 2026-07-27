import os
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import PlainTextResponse
from openai import AsyncOpenAI
from dotenv import load_dotenv

# 加载 .env 配置文件
load_dotenv()

app = FastAPI()

API_KEY = os.getenv("DEEPSEEK_API_KEY")
BASE_URL = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1")
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", "You are a helpful translator.")

# 初始化兼容 OpenAI 接口规范的 DeepSeek 客户端
client = AsyncOpenAI(api_key=API_KEY, base_url=BASE_URL)

@app.post("/translate", response_class=PlainTextResponse)
async def translate(request: Request):
    try:
        # 接收纯文本并解码，丢弃复杂的 JSON 解析
        text = (await request.body()).decode("utf-8")
        if not text.strip():
            return ""
        
        # 调用 DeepSeek API
        response = await client.chat.completions.create(
            model="deepseek-chat",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": text}
            ],
            temperature=0.3 # 0.3 偏向于稳定和精准的翻译
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("SERVER_PORT", 8989))
    # 启动本地服务
    uvicorn.run(app, host="127.0.0.1", port=port)