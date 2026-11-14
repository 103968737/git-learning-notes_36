# 04 API 与集成

Ollama 启动后就是一个本地 HTTP 服务，既能用原生 REST 接口，也能用 OpenAI 兼容接口。这篇给出常用端点、请求示例和接入现有系统的做法。

## 1. 服务地址

| 部署方式 | 地址 |
| --- | --- |
| Docker Compose | `http://localhost:11434`（容器内为 `http://ollama:11434`） |
| Windows 原生 Ollama | `http://127.0.0.1:11434` |

先确认服务活着：

```powershell
curl.exe http://localhost:11434/api/tags      # 列出已下载模型
curl.exe http://localhost:11434/api/ps        # 查看正在加载的模型
```

## 2. 原生 REST 接口

### 2.1 对话 /api/chat（推荐）

```powershell
$body = @{
  model    = "qwen2.5:7b"
  messages = @(
    @{ role = "system"; content = "你是一个简洁的中文助手。" },
    @{ role = "user";   content = "用一句话解释什么是量化。" }
  )
  stream   = $false
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri http://localhost:11434/api/chat `
  -Method Post -ContentType 'application/json; charset=utf-8' `
  -Body ([Text.Encoding]::UTF8.GetBytes($body)) |
  Select-Object -ExpandProperty message
```

等价 curl 写法：

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "qwen2.5:7b",
  "messages": [{"role": "user", "content": "你好"}],
  "stream": false
}'
```

响应核心字段：`message.content` 为回答文本，`done_reason` 表示结束原因，`eval_count` / `eval_duration` 可用来估算 tokens/s。

### 2.2 补全 /api/generate

适合单轮、无对话历史的场景：

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "写一个 PowerShell 函数判断端口是否被占用",
  "stream": false
}'
```

### 2.3 向量化 /api/embeddings

```bash
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text",
  "prompt": "本地部署大模型"
}'
```

返回 `embedding` 数组，可直接做余弦相似度检索（见 `examples/rag_demo.py`）。

## 3. 流式输出

把 `stream` 设为 `true` 时，服务端按行返回 NDJSON：

```
{"model":"qwen2.5:7b","message":{"role":"assistant","content":"你"},"done":false}
{"model":"qwen2.5:7b","message":{"role":"assistant","content":"好"},"done":false}
...
{"model":"qwen2.5:7b","message":{"role":"assistant","content":""},"done":true,...}
```

逐行 `json.loads` 并拼接 `message.content` 即可实现打字机效果，参考 `examples/chat.py`。

## 4. OpenAI 兼容接口

Ollama 内置了 `/v1` 前缀的兼容层，已有 OpenAI SDK 的项目只需改 `base_url`：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama",   # 本地服务不校验，填任意非空字符串
)

stream = client.chat.completions.create(
    model="qwen2.5:7b",
    messages=[{"role": "user", "content": "你好"}],
    stream=True,
)
for chunk in stream:
    delta = chunk.choices[0].delta.content
    if delta:
        print(delta, end="", flush=True)
```

| OpenAI 端点 | 本地地址 | 说明 |
| --- | --- | --- |
| `POST /v1/chat/completions` | `http://localhost:11434/v1/chat/completions` | 对话，主流 SDK 默认走这里 |
| `GET /v1/models` | `http://localhost:11434/v1/models` | 列出本地模型 |
| `POST /v1/embeddings` | `http://localhost:11434/v1/embeddings` | 向量化（需先拉对应模型） |

注意：兼容层不实现全部参数（如 `logprobs`、部分 `tool_choice` 组合），复杂特性请改用原生 `/api/*`。

## 5. 接入其他工具

| 工具 | 配置方式 |
| --- | --- |
| Open WebUI | `OLLAMA_BASE_URL=http://ollama:11434`（compose 已配好） |
| LangChain | `ChatOpenAI(base_url="http://localhost:11434/v1", api_key="ollama")` |
| Dify | 模型供应商选 OpenAI 兼容，Base URL 填 `http://<主机IP>:11434/v1` |
| VS Code 的 Continue / Cline | 提供商选 Ollama，地址 `http://localhost:11434` |
| 任意支持 OpenAI 协议的应用 | 改 Base URL + 模型名即可 |

## 6. 工程化建议

- **超时**：长回答 + 大模型时，客户端超时不要低于 120 秒；流式请求可设 300 秒。
- **重试**：对 `503`（模型加载中）做指数退避重试，最多 3 次。
- **预热**：服务刚启动时第一个请求要加载权重，可能慢几十秒；可用一次空请求或 `keep_alive` 预热。
- **并发**：`OLLAMA_NUM_PARALLEL` 不宜超过显存能承受的数量，否则会排队甚至 OOM。
- **安全**：Ollama 无鉴权。只在回环地址监听；确需局域网访问时，用反向代理加认证与 TLS，并限制来源 IP。

下一步：[05 常见问题](05-常见问题.md)
