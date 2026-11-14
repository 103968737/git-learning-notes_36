#!/usr/bin/env python3
"""本地知识库 RAG 最小实现（仅使用 Python 标准库）。

流程：读取 docs/*.md → 按段落切块 → 调用 Ollama 向量化 → 余弦相似度检索
      → 把命中的片段拼进提示词 → 交给本地模型回答。

准备：
    ollama pull nomic-embed-text
    ollama pull qwen2.5:7b

用法：
    python examples/rag_demo.py --question "显存 8GB 应该选哪个模型？"
    python examples/rag_demo.py --docs docs --top-k 5 --question "..."
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_HOST = "http://127.0.0.1:11434"
DEFAULT_CHAT_MODEL = "qwen2.5:7b"
DEFAULT_EMBED_MODEL = "nomic-embed-text"
CHUNK_SIZE = 500


def _post_json(url: str, payload: dict, timeout: float) -> dict:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def embed(host: str, model: str, text: str, timeout: float = 60.0) -> list[float]:
    """调用 /api/embeddings 获取文本向量。"""
    try:
        result = _post_json(
            f"{host.rstrip('/')}/api/embeddings",
            {"model": model, "prompt": text},
            timeout,
        )
    except urllib.error.HTTPError as exc:
        raise SystemExit(
            f"向量化失败（HTTP {exc.code}）。请先下载向量模型：ollama pull {model}"
        ) from exc
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"无法连接 Ollama（{host}）：{exc.reason}\n"
            "请先启动服务：docker compose up -d   或   ollama serve"
        ) from exc
    vector = result.get("embedding") or []
    if not vector:
        raise SystemExit(f"模型 {model} 未返回向量，请确认它支持 /api/embeddings。")
    return vector


def load_chunks(docs_dir: Path, chunk_size: int = CHUNK_SIZE) -> list[dict]:
    """把目录下所有 Markdown 按空行分段，并合并为约 chunk_size 字的块。"""
    chunks: list[dict] = []
    for path in sorted(docs_dir.rglob("*.md")):
        text = path.read_text(encoding="utf-8", errors="replace")
        buffer = ""
        for paragraph in text.split("\n\n"):
            paragraph = paragraph.strip()
            if not paragraph or paragraph.startswith("```"):
                continue
            if len(buffer) + len(paragraph) + 2 > chunk_size and buffer:
                chunks.append({"source": path.name, "text": buffer.strip()})
                buffer = ""
            buffer += paragraph + "\n\n"
        if buffer.strip():
            chunks.append({"source": path.name, "text": buffer.strip()})
    return chunks


def cosine_similarity(a: list[float], b: list[float]) -> float:
    if not a or not b:
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def retrieve(host: str, embed_model: str, chunks: list[dict], question: str, top_k: int):
    """对问题做向量化，返回相似度最高的 top_k 个片段。"""
    print(f"正在向量化 {len(chunks)} 个片段（模型 {embed_model}）...")
    for index, chunk in enumerate(chunks):
        chunk["vector"] = embed(host, embed_model, chunk["text"])
        if (index + 1) % 10 == 0:
            print(f"  已完成 {index + 1}/{len(chunks)}")
    question_vector = embed(host, embed_model, question)
    ranked = sorted(
        chunks,
        key=lambda c: cosine_similarity(question_vector, c["vector"]),
        reverse=True,
    )
    return ranked[:top_k]


def answer(host: str, model: str, question: str, hits: list[dict], timeout: float = 180.0) -> None:
    context = "\n\n".join(
        f"[来源 {i + 1}: {hit['source']}]\n{hit['text']}" for i, hit in enumerate(hits)
    )
    messages = [
        {
            "role": "system",
            "content": (
                "你是一个本地知识库助手。只依据【参考资料】回答，"
                "资料中没有的内容要明确说不知道，不要编造。回答末尾列出引用的来源编号。"
            ),
        },
        {
            "role": "user",
            "content": f"【参考资料】\n{context}\n\n【问题】\n{question}",
        },
    ]
    payload = {"model": model, "messages": messages, "stream": True}
    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                f"{host.rstrip('/')}/api/chat",
                data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                headers={"Content-Type": "application/json; charset=utf-8"},
                method="POST",
            ),
            timeout=timeout,
        ) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line:
                    continue
                event = json.loads(line)
                piece = (event.get("message") or {}).get("content", "")
                if piece:
                    print(piece, end="", flush=True)
                if event.get("done"):
                    break
        print()
    except urllib.error.URLError as exc:
        raise SystemExit(f"无法连接 Ollama：{exc.reason}") from exc


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="本地知识库 RAG 最小实现")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--model", default=DEFAULT_CHAT_MODEL, help="生成回答的模型")
    parser.add_argument("--embed-model", default=DEFAULT_EMBED_MODEL, help="向量化模型")
    parser.add_argument("--docs", default=str(Path(__file__).resolve().parent.parent / "docs"),
                        help="知识库目录（默认 ai-local-deploy/docs）")
    parser.add_argument("--question", required=True, help="要提问的问题")
    parser.add_argument("--top-k", type=int, default=4, help="召回片段数量")
    args = parser.parse_args()

    docs_dir = Path(args.docs)
    if not docs_dir.is_dir():
        raise SystemExit(f"知识库目录不存在：{docs_dir}")

    chunks = load_chunks(docs_dir)
    if not chunks:
        raise SystemExit(f"目录中没有可用的 Markdown：{docs_dir}")
    print(f"知识库：{docs_dir}（{len(chunks)} 个片段）")

    hits = retrieve(args.host, args.embed_model, chunks, args.question, args.top_k)
    print("\n召回片段：")
    for i, hit in enumerate(hits, 1):
        score = cosine_similarity(hits[0]["vector"], hit["vector"]) if i > 1 else 1.0
        print(f"  {i}. {hit['source']}（相似度 {score:.3f}）")

    print("\n回答：")
    answer(args.host, args.model, args.question, hits)


if __name__ == "__main__":
    main()
