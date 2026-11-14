# Git 学习笔记（学号后两位：36）

本项目记录了我从零开始学习 Git 的完整过程，包含常用命令总结、分支协作与冲突解决记录；同时在里面完成了一份 **AI 本地部署** 实战项目。希望能帮助到同样刚接触 Git 的同学。

## 📚 项目目录

- [x] [01-basic.md](01-basic.md)：基础本地库操作（init, add, commit, log）
- [x] [02-remote.md](02-remote.md)：远程仓库配置（SSH 443 端口避坑指南）
- [x] [03-branch.md](03-branch.md)：分支管理与冲突解决（含一次真实的 add/add 冲突实录）
- [x] [ai-local-deploy/](ai-local-deploy/README.md)：AI 本地部署实战（Ollama + Open WebUI）
- [x] [docs/五看三定分析.md](docs/五看三定分析.md)：用华为「五看三定」拆解本项目

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

## 🌿 分支模型

| 分支 | 用途 |
| --- | --- |
| `main` | 稳定版本，只接受合并 |
| `feature/*` | 单个功能或文档，合并后删除 |
| `dev` | 集成联调 |

合并统一使用 `git merge --no-ff` 保留分支上下文；一次真实冲突的产生与解决过程记录在 [03-branch.md](03-branch.md)。

## 📊 项目分析

用华为「五看三定」从行业、市场、竞争、自身、机会五个维度分析本项目，并给出战略控制点、目标与落地策略，详见 [docs/五看三定分析.md](docs/五看三定分析.md)。

## 🤝 参与讨论

欢迎在 [Issues](../../issues) 里提问或讨论，也可以直接使用下面的模板：

- [Bug 报告](../../issues/new?template=bug_report.md)：部署失败、脚本报错
- [功能建议](../../issues/new?template=feature_request.md)：想支持的新模型/新场景
- [讨论议题](docs/讨论议题.md)：5 个开放问题，欢迎补充实测数据

如果这个项目对你有帮助，欢迎点一个 **Star** 并 **Watch** 关注后续更新。

## 🛠️ 使用的技术

- Git / GitHub（分支、合并、冲突解决）
- Markdown
- Docker Compose、Ollama、Open WebUI
- Python 3（标准库 + 可选 openai SDK）
- PowerShell 7 / Windows PowerShell 5.1

## 📁 仓库结构

```
.
├── README.md
├── 01-basic.md / 02-remote.md / 03-branch.md   # Git 学习笔记
├── ai-local-deploy/                            # 本地 AI 部署项目
│   ├── docker-compose.yml
│   ├── docs/                                   # 5 篇部署文档
│   ├── scripts/                                # 自检 / 启动 / 停止 / 拉模型
│   └── examples/                               # 对话 / RAG / OpenAI SDK 示例
├── docs/
│   ├── 五看三定分析.md
│   └── 讨论议题.md
├── .github/ISSUE_TEMPLATE/                     # Issue 模板
├── CONTRIBUTING.md                             # 贡献指南
└── LICENSE
```

## 📄 开源协议

本项目遵循 [MIT License](LICENSE) 开源协议。

## 🙌 贡献

提交前请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，分支命名、提交信息格式和本地验证步骤都在里面。
