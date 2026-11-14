# 贡献指南

感谢你愿意参与这个项目。为了让协作顺畅，提交前请先花两分钟读完这份约定。

## 1. 开始之前

- 仓库地址：<https://github.com/103968737/git-learning-notes_36>
- 先浏览 [README.md](README.md) 了解项目结构；
- 大改动请先开 Issue 讨论，避免做无用功；
- 小修小补（错别字、链接失效）可以直接提 PR。

## 2. 分支规范

| 分支 | 用途 | 示例 |
| --- | --- | --- |
| `main` | 稳定版本，只接受合并 | — |
| `feature/<主题>` | 新功能或文档 | `feature/rag-demo` |
| `fix/<主题>` | 缺陷修复 | `fix/port-conflict` |
| `docs/<主题>` | 纯文档改动 | `docs/branch-guide` |

- 从最新的 `main` 切出，不要从旧提交开始；
- 分支名用小写字母、数字和短横线，不超过 40 个字符；
- 合并统一使用 `git merge --no-ff`，保留分支上下文。

## 3. 提交信息格式

采用 Conventional Commits，格式：`<类型>: <简短说明>`

| 类型 | 含义 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 修复缺陷 |
| `docs` | 只改文档 |
| `refactor` | 重构（不改变行为） |
| `test` | 测试相关 |
| `chore` | 构建、依赖、杂项 |

示例：

```
feat: 新增本地 RAG 示例脚本
docs: 补充 8GB 显存下的模型选型建议
fix: 修正 check-env 显存单位换算
```

要求：一句话说清"做了什么"，不要在标题里写"update"、"修改一下"这类无信息量的描述。

## 4. 提交流程

```bash
git switch main
git pull --ff-only
git switch -c feature/your-topic
# ... 修改文件 ...
git add <改动文件>
git commit -m "feat: 你的改动"
git push -u origin feature/your-topic
```

然后在 GitHub 上发起 Pull Request，描述里写清楚：改了什么、为什么改、怎么验证。

## 5. 本地验证清单

提交前至少跑一遍：

```powershell
# 1. Python 示例能编译
python -m py_compile ai-local-deploy/examples/*.py

# 2. PowerShell 脚本语法正确（错误数应为 0）
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path 'ai-local-deploy/scripts/check-env.ps1'), [ref]$null, [ref]$errors) | Out-Null
$errors.Count

# 3. 环境自检可运行（已装 Docker/Ollama 时）
.\ai-local-deploy\scripts\check-env.ps1
```

如果改动涉及 Markdown，请确认新增的相对链接都能打开。

## 6. Issue 规范

- Bug 报告请用 [Bug 模板](.github/ISSUE_TEMPLATE/bug_report.md)，附上系统版本、显存、报错原文；
- 功能建议请用 [功能模板](.github/ISSUE_TEMPLATE/feature_request.md)，说明使用场景；
- 提问前先搜索已有 Issue，避免重复。

## 7. 代码风格

- Python：标准库优先，4 空格缩进，函数写 docstring，错误要给出可执行的修复提示；
- PowerShell：兼容 Windows PowerShell 5.1，脚本注释用中文，输出尽量带颜色区分状态；
- Markdown：一个文件只讲一件事，标题层级不超过三级，命令统一放在代码块里。

## 8. 行为准则

- 对事不对人，review 意见聚焦代码与文档；
- 不提交与本项目无关的大文件、模型权重或个人隐私数据；
- 不刷 star、不刷无意义的 Issue 评论。
