import os
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import PlainTextResponse, StreamingResponse
from openai import AsyncOpenAI
from dotenv import load_dotenv

# 加载 .env 配置文件
load_dotenv()

app = FastAPI()

API_KEY = os.getenv("DEEPSEEK_API_KEY")
BASE_URL = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1")
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", "You are a helpful translator.")

# ==========================================
# 【核心修复】：直接将你的完整 Prompt 硬编码写入，彻底告别读取失败
# ==========================================
EXPLAIN_PROMPT = """你是一个精通认知语言学与英语词汇演变的专家。我的目标是拒绝“死记硬背中文对译”，通过“物理画面”与“隐喻演变”来深刻理解英语单词的本质，从而精准把控词汇、提高写作与阅读深度。

当我向你发送一个【单词】或【带有生词的句子】时，请严格按照以下 4 个步骤进行拆解分析：

1. **核心物理画面/动作 (The Physical Core / Physical Motion)**
   * 用最直观、画面感最强的语言，说明这个词最原始的“物理画面”或“物理动作”是什么？（如：拉缰绳、把水倒出来、盖上盖子等）
   * 如果有词根词缀的视觉含义，请一并简观指出。

2. **隐喻与抽象发散 (Metaphorical Extension)**
   * 作者是如何把这个“物理画面”借用/隐喻到抽象场景中的？（例如：从物理上的“拉住马缰绳”发散到抽象的“控制通货膨胀”/“约束情绪”）。
   * 这种发散背后的逻辑联系是什么？

3. **原生精准语境与写作示范 (Context & Precision)**
   * 提供 2 个地道的高级英文例句（最好涵盖社科、政治评论或文学场景）。
   * **精准辨析**：请说明这个词和它的“中文近义词”在感官画面或侧重点上有何微妙区别（避免形近词/近义词混淆）。

4. **一句话记忆锚点 (Memory Anchor)**
   * 用一句话概括：**【物理画面】 ➔ 【抽象隐喻】**，帮助我脑海中直接建立【形 - 画面 - 义】的直连，拒绝中译英。
"""

# 初始化兼容 OpenAI 接口规范的 DeepSeek 客户端
client = AsyncOpenAI(api_key=API_KEY, base_url=BASE_URL)

@app.post("/translate", response_class=PlainTextResponse)
async def translate(request: Request):
    try:
        text = (await request.body()).decode("utf-8")
        if not text.strip():
            return ""
        
        response = await client.chat.completions.create(
            model="deepseek-chat",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": text}
            ],
            temperature=0.3
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/explain")
async def explain(request: Request):
    try:
        text = (await request.body()).decode("utf-8")
        if not text.strip():
            return PlainTextResponse("")
        
        async def generate():
            try:
                response = await client.chat.completions.create(
                    model="deepseek-chat",
                    messages=[
                        {"role": "system", "content": EXPLAIN_PROMPT},
                        {"role": "user", "content": text}
                    ],
                    temperature=0.3,
                    stream=True
                )
                async for chunk in response:
                    if chunk.choices[0].delta.content is not None:
                        yield chunk.choices[0].delta.content
            except Exception as e:
                yield f"\n\n[API 请求错误: {str(e)}]"
        
        return StreamingResponse(generate(), media_type="text/plain")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("SERVER_PORT", 8989))
    uvicorn.run(app, host="127.0.0.1", port=port)