# 03 分支管理速记

> 先记一版命令，细节等整理完再补。

| 操作 | 命令 |
| --- | --- |
| 建分支 | `git switch -c feature/xxx` |
| 切分支 | `git switch main` |
| 看分支 | `git branch -vv` |
| 合并 | `git merge --no-ff feature/xxx` |
| 推分支 | `git push -u origin feature/xxx` |
| 看分支图 | `git log --graph --all --oneline` |

合并统一用 `--no-ff`，保留分支上下文。冲突解决、快进与 `--no-ff` 的区别待补充。
