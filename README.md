# Git 学习笔记（学号后两位：36）

本项目记录了我从零开始学习 Git 的完整过程，包含常用命令总结、踩坑记录及解决方案；同时在里面完成了一份 **AI 本地部署** 实战项目。希望能帮助到同样刚接触 Git 的同学。

## 📚 项目目录

- [x] [01-basic.md](01-basic.md)：基础本地库操作（init, add, commit, log）
- [x] [02-remote.md](02-remote.md)：远程仓库配置（SSH 443 端口避坑指南）
- [ ] 03-branch.md：分支管理与合并（含冲突解决记录）
- [x] [ai-local-deploy/](ai-local-deploy/README.md)：AI 本地部署实战（Ollama + Open WebUI）

## 🤖 AI 本地部署项目

`ai-local-deploy/` 是一套可以直接跑起来的本地大模型部署方案，模型权重、推理服务和聊天界面全部运行在本机，数据不出本地、断网可用。

- 一条命令拉起 **Ollama（推理服务）+ Open WebUI（聊天界面）**，也支持 Windows 原生安装；
- 自带环境自检、一键启动/停止、模型拉取脚本；
- 提供流式对话、本地知识库 RAG、OpenAI SDK 接入三个可运行示例；
- 附带环境准备、模型量化、方案对比、API 集成、常见问题五篇文档。

快速开始：

```powershell
cd ai-local-deploy
Copy-Item .env.example .env
docker compose up -d
docker compose exec ollama ollama pull qwen2.5:7b
```

启动后访问 <http://localhost:3000> 即可对话。详见 [ai-local-deploy/README.md](ai-local-deploy/README.md)。

## 🛠️ 使用的技术

- Git / GitHub
- Markdown
- Docker Compose、Ollama、Open WebUI
- Python 3（标准库 + 可选 openai SDK）

## 📄 开源协议

本项目遵循 [MIT License](LICENSE) 开源协议。
