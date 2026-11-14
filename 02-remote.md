# 02 远程推送笔记

记录把本地仓库连到 GitHub、配置 SSH、解决 22 端口被拒绝，以及日常的 fetch / pull / push。

## 1. 远程仓库与跟踪分支

`git init` 之后仓库只在本地。要多人协作或备份，需要关联一个远程仓库：

```powershell
git remote -v          # 查看已关联的远程
git branch -vv         # 查看本地分支跟踪的是哪个远程分支
```

`origin` 是 `git clone` 默认给远程起的名字，也可以自己改成 `upstream` 等。`git branch -vv` 里 `[origin/main: ahead 1]` 表示本地比远程多一个提交，`: behind 2` 表示少了两个。

## 2. 关联远程仓库

```powershell
# 推荐 SSH（配好 key 后免密码）
git remote add origin git@github.com:103968737/git-learning-notes_36.git

# 或者 HTTPS（需要 token 认证）
git remote add origin https://github.com/103968737/git-learning-notes_36.git
```

常用维护命令：

```powershell
git remote -v
git remote set-url origin <新地址>   # 换地址
git remote rename origin upstream    # 改名
git remote remove origin             # 删除关联
```

SSH 与 HTTPS 的取舍：

| | SSH | HTTPS |
| --- | --- | --- |
| 认证方式 | 公钥，配置一次长期有效 | 账号 + Personal Access Token |
| 网络限制 | 22 端口可能被封（需换 443） | 走 443，一般不被拦 |
| 适合场景 | 日常开发、自动化 | 临时环境、公司网络限制 |

## 3. 首次推送

```powershell
git push -u origin main
```

`-u`（`--set-upstream`）会把本地 `main` 和 `origin/main` 建立跟踪关系，之后直接 `git push` / `git pull` 即可，不用再写远程名和分支名。

## 4. 日常同步：fetch、pull、push

```powershell
git fetch origin          # 只下载远程更新，不动工作区
git status -sb            # 看落后/领先多少
git pull --ff-only        # 只允许快进合并，最安全
git pull --rebase         # 把本地提交挪到远程更新之后
git push
```

- `fetch` 是"看一眼远程有什么"，不会改本地文件；
- `pull` = `fetch` + 合并，合并方式取决于 `--ff-only` / `--rebase` / 默认 merge；
- 拿不准时先用 `git pull --ff-only`：能快进就快进，有分叉会直接报错，不会悄悄生成合并提交。

`pull --rebase` 会让历史保持一条直线，适合个人分支；多人共享的分支不要随意 rebase。

## 5. 配置 SSH key

```powershell
ssh-keygen -t ed25519 -C "103968737@qq.com"
```

连续回车即可（默认路径 `~/.ssh/id_ed25519`，密码可留空）。然后查看公钥并复制：

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

到 GitHub → Settings → SSH and GPG keys → New SSH key，粘贴整行公钥。验证：

```powershell
ssh -T git@github.com
# Hi 103968737! You've successfully authenticated, but GitHub does not provide shell access.
```

看到 `Hi 用户名` 就说明鉴权成功。注意这台机器的 Windows 自带的是 `C:\Windows\System32\OpenSSH\ssh.exe`，而 Git 自带的 MSYS `ssh` 在部分受限环境里会报管道错误，必要时显式指定前者。

## 6. 22 端口被拒绝的解决办法

**现象**：

```
ssh: connect to host github.com port 22: Connection refused
fatal: Could not read from remote repository.
```

**原因**：校园网、公司网络或防火墙拦截了 22 端口，不是 key 配错了。

**解决**：让 GitHub 走 443 端口。编辑 `~/.ssh/config`（没有就新建）：

```
Host github.com
  HostName ssh.github.com
  Port 443
  User git
```

再次执行 `ssh -T git@github.com`，出现 `Hi ...` 即成功，之后 `git push` 会自动走 443。

备选方案：改用 HTTPS 地址 + Personal Access Token（GitHub 已不支持密码认证），把 token 当作密码使用。

## 7. 代理配置

如果拉取或推送一直超时，可以给 Git 配置 HTTP 代理（仅对 HTTPS 生效）：

```powershell
git config --global http.proxy http://127.0.0.1:7890
git config --global --unset http.proxy    # 取消代理
```

注意：**`http.proxy` 对 SSH 连接无效**。SSH 要走代理需要在 `~/.ssh/config` 里配 `ProxyCommand`，或者直接改用 443 方案。

## 8. 常见报错对照表

| 报错 | 原因 | 解决 |
| --- | --- | --- |
| `Permission denied (publickey)` | 公钥没加到 GitHub，或加载的不是同一个 key | `ssh -vT git@github.com` 看用了哪个 key，重新添加 |
| `Connection refused` / `Connection timed out` | 22 端口被封 | 改走 `ssh.github.com:443` |
| `Host key verification failed` | 首次连接或服务器指纹变化 | 确认后删除 `known_hosts` 中对应条目重新连接 |
| `! [rejected] main -> main (non-fast-forward)` | 远程有本地没有的提交 | 先 `git pull --rebase` 再 `push` |
| `fatal: refusing to merge unrelated histories` | 两个仓库历史不相干 | 确认后加 `--allow-unrelated-histories` |
| `remote: Support for password authentication was removed` | HTTPS 用了账号密码 | 改用 Personal Access Token |
| `error: failed to push some refs` | 分支保护或权限不足 | 检查仓库权限、分支保护规则 |

推送被拒时**不要**第一反应就 `git push -f`：强推会覆盖远程其他人的提交，先 `pull` 看看到底差了什么。

## 9. 本项目实际的远程配置

```powershell
git remote -v
# origin  git@github.com:103968737/git-learning-notes_36.git (fetch)
# origin  git@github.com:103968737/git-learning-notes_36.git (push)
```

对应的 `~/.ssh/config` 已把 `github.com` 指向 `ssh.github.com:443`，这就是 22 端口被封后的实际落地方案。验证远程是否可达：

```powershell
git ls-remote --heads origin
git fetch origin
git status -sb
```

## 10. 速查表

```powershell
git remote -v                    # 看远程
git remote add origin <url>      # 关联远程
git push -u origin main          # 首次推送并建立跟踪
git push                         # 日常推送
git fetch origin                 # 只下载不合并
git pull --ff-only               # 安全拉取
git status -sb                   # 看领先/落后
ssh -T git@github.com            # 测试 SSH 鉴权
```

分支合并、冲突处理等进阶内容见 [03-branch.md](03-branch.md)。
