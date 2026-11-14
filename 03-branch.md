# 03 分支管理与冲突解决

> 合并说明：本文件由 `main` 上的速记草稿与 `feature/branch-guide` 分支上的完整版合并而来。
> 合并时发生 add/add 冲突，解决策略是「结构与原理采用完整版，草稿的命令速查表保留在文末」。

## 1. 分支模型

| 分支 | 用途 | 说明 |
| --- | --- | --- |
| `main` | 稳定版本 | 只接受合并，保证随时可演示 |
| `feature/*` | 单个功能或文档 | 从 `main` 切出，合并后删除 |
| `dev` | 集成联调 | 多个 feature 先汇合，再合回 `main` |

三条原则：

1. `main` 上不直接堆功能提交，只做合并与发布；
2. 分支名要体现意图，例如 `feature/rag-demo`、`docs/branch-guide`；
3. 合并统一使用 `--no-ff`，保留"这里曾经有过一个分支"的上下文。

## 2. 常用命令

| 操作 | 命令 |
| --- | --- |
| 创建并切换分支 | `git switch -c feature/xxx` |
| 切换分支 | `git switch main` |
| 查看本地分支与跟踪关系 | `git branch -vv` |
| 查看所有分支（含远程） | `git branch -a` |
| 推送新分支并建立跟踪 | `git push -u origin feature/xxx` |
| 合并（保留合并节点） | `git merge --no-ff feature/xxx` |
| 查看待合并的提交 | `git log --oneline main..feature/xxx` |
| 查看分支图 | `git log --graph --all --oneline` |
| 删除已合并的本地分支 | `git branch -d feature/xxx` |
| 删除远程分支 | `git push origin --delete feature/xxx` |

## 3. 快进合并与 --no-ff 的区别

- **快进（fast-forward）**：目标分支没有新提交时，Git 直接把指针前移，历史是一条直线，看不出"曾经有分支"。
- **`--no-ff`**：强制生成一个合并提交，保留分支从哪来、合到哪去，方便回溯和回滚。

本项目选择 `--no-ff`，因为这是一个教学项目，**分支存在的痕迹本身就是要展示的内容**。

## 4. 冲突是怎么产生的

Git 只有在**同一文件的同一区域**被两个分支分别修改时才会停下来让人决策。常见三类：

1. 修改/修改：同一行被两边改成不同内容；
2. 新增/新增（add/add）：两个分支各自创建了同名文件；
3. 修改/删除：一边改、一边删。

冲突时 Git 会暂停合并，在工作区文件里插入标记：

```
<<<<<<< HEAD
当前分支（main）的内容
=======
被合并分支（feature/xxx）的内容
>>>>>>> feature/xxx
```

## 5. 解决冲突的六个步骤

1. `git status` 确认哪些文件处于 `both modified` / `both added`；
2. 打开冲突文件，逐个定位 `<<<<<<<`、`=======`、`>>>>>>>`；
3. 逐段决定：保留哪边、还是两边融合，删除标记行；
4. 保存文件，确认没有残留标记；
5. `git add <文件>` 告诉 Git 已经解决；
6. `git commit`（合并场景直接沿用默认合并信息即可）。

想放弃这次合并时，执行 `git merge --abort` 可以回到合并前。

## 6. 本次实操记录

**背景**：`main` 上先提交了一版分支管理速记，`feature/branch-guide` 分支上提交了完整版，两边各自创建了 `03-branch.md`。

| 步骤 | 命令 | 结果 |
| --- | --- | --- |
| 创建分支 | `git switch -c feature/branch-guide` | 从 `main` 切出 |
| 分支提交 | `git add 03-branch.md` + `git commit` | feature 上有完整版 |
| 主干提交 | 切回 `main` 后写速记并 `git commit` | main 上有草稿版 |
| 合并 | `git merge --no-ff feature/branch-guide` | **add/add 冲突**，合并暂停 |
| 解决 | 保留完整版并吸收草稿的速查表，`git add` + `git commit` | 生成双亲合并提交 |
| 推送 | `git push origin main`、`git push origin feature/branch-guide` | 两个分支在 GitHub 上可见 |

冲突标记长这样（两边都创建了同一文件时）：

```
<<<<<<< HEAD
# 03 分支管理速记
=======
# 03 分支管理与冲突解决
>>>>>>> feature/branch-guide
```

本次的取舍是：**结构、原理、冲突解决步骤以完整版为准，草稿里的命令速查表保留在文末**，最后删除全部标记行再提交。

## 7. 减少冲突的习惯

- 小步提交、频繁同步：开工前 `git switch main && git pull`，合并前先把 `main` 合进特性分支；
- 按文件/模块分工，避免多人同时改同一段；
- 长分支定期 rebase 或 merge 主干，别攒到最后一次合；
- 冲突时先沟通语义，再动手改文本——Git 只能告诉你"哪里不一样"，不能告诉你"应该是什么"。

## 8. 速查表

```bash
git switch -c feature/xxx       # 建分支
git push -u origin feature/xxx  # 推分支
git merge --no-ff feature/xxx   # 合并并保留节点
git log --graph --all --oneline # 看分支图
git merge --abort               # 放弃这次合并
```
