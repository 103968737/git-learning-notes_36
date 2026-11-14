# 01 基础操作笔记

记录从零初始化仓库、暂存、提交、查看历史与撤销的完整过程，以及实际踩过的坑。

## 1. 先理解三个区域

```
工作区（Working Directory） --git add--> 暂存区（Index） --git commit--> 版本库（Repository）
```

- `git add`：把工作区的改动放进暂存区；
- `git commit`：把暂存区的内容固化成一次提交；
- `git status` / `git diff`：只是看，不改变任何东西。

大部分"我明明改了却没提交上去"的问题，都是因为只做了第一步、漏了第二步。

## 2. 初始化仓库与配置身份

```powershell
mkdir my-project
cd my-project
git init
```

新建仓库默认分支名可能是 `master`，建议统一改成 `main`：

```powershell
git config --global init.defaultBranch main
```

提交前必须配置作者信息，否则 `git commit` 会直接报错：

```powershell
git config --global user.name "你的名字"
git config --global user.email "you@example.com"
git config --list --show-origin
```

注意：`user.name` / `user.email` 只决定提交记录里显示的作者，**和推送权限无关**；推送能不能成功取决于 SSH key 或 token。

## 3. 查看状态与暂存

```powershell
git status            # 完整状态：哪些已暂存、哪些未跟踪
git status -s         # 简写：M 修改、A 新增、?? 未跟踪
```

暂存与取消暂存：

```powershell
git add README.md     # 单个文件
git add .             # 当前目录及子目录的所有改动
git add -A            # 整个仓库（含删除）
git restore --staged README.md   # 取消暂存，改动仍保留在工作区
```

`git add .` 和 `git add -A` 的区别：前者只处理当前目录，后者覆盖全仓库；日常在仓库根目录操作时两者基本等价。

## 4. 提交

```powershell
git commit -m "docs: 新增 README"
git commit -am "fix: 修正链接"      # 只能提交已跟踪文件，新文件仍需先 add
git commit --amend --no-edit        # 把漏掉的文件补进上一次提交
```

提交信息建议用 `<类型>: <说明>` 的格式，类型包括 `feat`、`fix`、`docs`、`refactor`、`test`、`chore`。标题控制在 50 字以内，写清楚"做了什么"，不要用 `update`、`修改一下` 这种无法回溯的描述。

> `--amend` 会改写上一次提交的哈希。**已推送到远程的提交不要 amend**，否则需要 force push，容易覆盖别人的工作。

## 5. 查看历史与差异

```powershell
git log --oneline --graph --decorate -10   # 最常用：单行 + 分支图 + 引用
git log -p -1                              # 最近一次提交的完整 diff
git show <commit>                          # 某次提交改了什么
git diff                                   # 工作区 vs 暂存区
git diff --staged                          # 暂存区 vs 最后一次提交
git diff main..feature                     # 两个分支之间的差异
```

看历史时优先用 `--oneline --graph`，能一眼看出哪次是合并、分支从哪里分出去。

## 6. 撤销：分四种场景

| 场景 | 命令 | 说明 |
| --- | --- | --- |
| 改了文件但还没 add | `git restore <文件>` | 用版本库里的版本覆盖工作区，**改动会丢** |
| 已 add，想撤回暂存 | `git restore --staged <文件>` | 改动还在工作区 |
| 已 commit，想改内容或信息 | `git commit --amend` | 仅限本地未推送 |
| 已 commit，想退回某个版本 | `git reset --soft/--mixed/--hard <hash>` | `--hard` 会丢弃工作区改动，慎用 |
| 已推送，想撤销 | `git revert <hash>` | 生成一个反向提交，历史不被改写，最安全 |

记忆方法：**还没推送就改历史，已经推送就加新提交**。

## 7. 忽略文件 .gitignore

只对**未跟踪**的文件生效，按行写规则：

```gitignore
# 本地配置
.env

# 依赖与缓存
node_modules/
__pycache__/
*.pyc

# 日志与临时文件
*.log
*.tmp

# 例外：不要忽略模板文件
!.env.example
```

几个容易踩的点：

- 已经被跟踪的文件，写进 `.gitignore` 也不会生效，需要先 `git rm --cached <文件>` 再提交；
- Git 不跟踪空目录，需要保留目录结构时放一个空的 `.gitkeep`；
- 路径中的 `/` 表示目录，`*` 匹配任意字符，`!` 表示例外。

本项目里 [`ai-local-deploy/.gitignore`](ai-local-deploy/.gitignore) 就是一个实际例子：忽略 `.env`、`__pycache__`、`data/`，但保留 `.env.example`。

## 8. 本项目的第一次提交

```powershell
git init
git add 01-basic.md 02-remote.md README.md
git commit -m "期末作业：第一次完整提交"
git log --oneline
```

三个文件一次性进入版本库，这也是后面所有分支操作的起点。

## 9. 踩坑记录

1. **每次都提示 LF 将被替换为 CRLF**
   这是 Windows 换行符转换的提示，不影响文件内容。想彻底统一可以加 `.gitattributes`：`* text=auto`；团队协作时建议统一，避免整文件 diff。

2. **把不该提交的文件提交了**
   不要直接删文件了事，用 `git rm --cached <文件>` 停止跟踪，再补进 `.gitignore`，最后单独提交一次。

3. **中文文件名显示成八进制转义**
   执行 `git config --global core.quotepath false`，日志和状态就会正常显示中文。

4. **提交信息写得太随意**
   一周后回头看 `update`、`fix bug` 这类提交，完全不知道改了什么。提交信息是写给未来的自己看的。

5. **以为 commit 就等于上传**
   `commit` 只写到本地版本库，`push` 才会上传到远程。两个动作要分开理解。

## 10. 自查清单

- [ ] `git status` 显示 `working tree clean`
- [ ] 提交信息能说清"做了什么"
- [ ] 敏感文件（密码、token、`.env`）没有进入版本库
- [ ] `git log --oneline --graph` 的历史清晰可读
- [ ] 需要撤销时，确认这次提交是否已经推送
