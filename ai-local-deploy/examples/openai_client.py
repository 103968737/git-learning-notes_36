#!/usr/bin/env python3
"""使用 OpenAI 官方 SDK 调用本地 Ollama（OpenAI 兼容接口）。

准备：
    pip install -r examples/requirements.txt

用法：
    python examples/openai_client.py --prompt "写一个 Python 快速排序"
    python examples/openai_client.py --model qwen2.5:7b --prompt "解释什么是量化"
"""

from __future__ import annotations

import argparse
import sys

try:
    from openai import OpenAI
except ImportError:
    raise SystemExit(
        "缺少依赖：openai。请先执行：pip install -r examples/requirements.txt"
    )


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="OpenAI SDK 调用本地 Ollama")
    parser.add_argument("--base-url", default="http://127.0.0.1:11434/v1",
                        help="OpenAI 兼容地址（注意保留 /v1）")
    parser.add_argument("--model", default="qwen2.5:7b")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--temperature", type=float, default=0.7)
    args = parser.parse_args()

    client = OpenAI(base_url=args.base_url, api_key="ollama")

    try:
        stream = client.chat.completions.create(
            model=args.model,
            messages=[
                {"role": "system", "content": "你是一个简洁的中文助手。"},
                {"role": "user", "content": args.prompt},
            ],
            temperature=args.temperature,
            stream=True,
        )
        for chunk in stream:
            if not chunk.choices:
                continue
            piece = chunk.choices[0].delta.content
            if piece:
                print(piece, end="", flush=True)
        print()
    except Exception as exc:  # noqa: BLE001 - 示例代码统一提示
        raise SystemExit(
            f"调用失败：{exc}\n"
            "请确认：1) Ollama 已启动；2) 模型已下载；3) base-url 以 /v1 结尾。"
        ) from exc


if __name__ == "__main__":
    main()
