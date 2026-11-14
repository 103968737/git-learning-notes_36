#!/usr/bin/env python3
"""本地 Ollama 流式对话客户端（仅使用 Python 标准库）。

用法：
    python examples/chat.py --model qwen2.5:7b --prompt "用三句话解释 RAG"
    python examples/chat.py --model qwen2.5:7b          # 进入交互式多轮对话
    python examples/chat.py --list                     # 列出本地已下载模型
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request

DEFAULT_HOST = "http://127.0.0.1:11434"
DEFAULT_MODEL = "qwen2.5:7b"
DEFAULT_SYSTEM = "你是一个严谨、简洁的中文助手，回答使用 Markdown。"
EXIT_COMMANDS = {"/exit", "/quit", "exit", "quit"}
RESET_COMMANDS = {"/reset", "reset"}


def _normalize_host(host: str) -> str:
    return host.rstrip("/")


def _request_json(url: str, payload: dict | None, timeout: float) -> urllib.request.Request:
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    return urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="GET" if data is None else "POST",
    )


def list_models(host: str, timeout: float = 10.0) -> list[str]:
    """读取 /api/tags，返回本地已安装的模型名列表。"""
    url = f"{_normalize_host(host)}/api/tags"
    with urllib.request.urlopen(_request_json(url, None, timeout), timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))
    return [item.get("name", "") for item in data.get("models", [])]


def stream_chat(host: str, model: str, messages: list[dict], timeout: float = 180.0):
    """向 /api/chat 发起流式请求，逐段产出回答文本。"""
    url = f"{_normalize_host(host)}/api/chat"
    payload = {"model": model, "messages": messages, "stream": True}
    request = _request_json(url, payload, timeout)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if event.get("error"):
                    raise RuntimeError(event["error"])
                content = (event.get("message") or {}).get("content", "")
                if content:
                    yield content
                if event.get("done"):
                    break
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(
            f"请求失败：HTTP {exc.code}\n{detail}\n"
            f"请确认模型已下载：ollama pull {model}"
        ) from exc
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"无法连接 Ollama（{host}）：{exc.reason}\n"
            "请先启动服务：docker compose up -d   或   ollama serve"
        ) from exc


def ask(host: str, model: str, messages: list[dict], timeout: float) -> str:
    """打印流式回答并返回完整文本。"""
    chunks: list[str] = []
    for piece in stream_chat(host, model, messages, timeout=timeout):
        print(piece, end="", flush=True)
        chunks.append(piece)
    print()
    return "".join(chunks)


def interactive(host: str, model: str, system: str, timeout: float) -> None:
    messages: list[dict] = [{"role": "system", "content": system}]
    print(f"已连接 {host}，模型 {model}。输入 /exit 退出，/reset 清空上下文。")
    while True:
        try:
            user_input = input("\n你：").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n已退出。")
            return
        if not user_input:
            continue
        if user_input.lower() in EXIT_COMMANDS:
            print("已退出。")
            return
        if user_input.lower() in RESET_COMMANDS:
            messages = [{"role": "system", "content": system}]
            print("上下文已清空。")
            continue

        messages.append({"role": "user", "content": user_input})
        print("AI：", end="", flush=True)
        try:
            reply = ask(host, model, messages, timeout)
        except SystemExit as exc:
            print(exc)
            return
        messages.append({"role": "assistant", "content": reply})


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="本地 Ollama 流式对话客户端")
    parser.add_argument("--host", default=DEFAULT_HOST, help=f"Ollama 地址（默认 {DEFAULT_HOST}）")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"模型名（默认 {DEFAULT_MODEL}）")
    parser.add_argument("--system", default=DEFAULT_SYSTEM, help="系统提示词")
    parser.add_argument("--prompt", help="单轮提问；省略则进入交互模式")
    parser.add_argument("--timeout", type=float, default=180.0, help="单次请求超时秒数")
    parser.add_argument("--list", action="store_true", help="列出本地已下载模型后退出")
    args = parser.parse_args()

    if args.list:
        try:
            models = list_models(args.host, timeout=args.timeout)
        except urllib.error.URLError as exc:
            raise SystemExit(f"无法连接 Ollama（{args.host}）：{exc.reason}") from exc
        if not models:
            print("本地还没有模型，先执行：ollama pull qwen2.5:7b")
        for name in models:
            print(name)
        return

    messages = [
        {"role": "system", "content": args.system},
        {"role": "user", "content": args.prompt},
    ] if args.prompt else None

    if messages is not None:
        ask(args.host, args.model, messages, args.timeout)
    else:
        interactive(args.host, args.model, args.system, args.timeout)


if __name__ == "__main__":
    main()
