# 新开发者入职指南（开发者）

目标：使用本机 SSH 密钥登录远程主机，使用 VS Code Remote-SSH 或终端进行开发，并在项目工作区内协作。

## 1. 生成 SSH 密钥（本地电脑）
在你的电脑本地（不要在远程主机）生成密钥：

macOS/Linux（终端）：
```bash
ssh-keygen -t ed25519 -C "you@host"
# 公钥：~/.ssh/id_ed25519.pub  私钥：~/.ssh/id_ed25519（请务必妥善保管私钥）
```

Windows：使用 PowerShell（OpenSSH）或 Git Bash 执行同上命令。

将公钥（`.pub` 内容）发送给管理员，不要发送私钥。

## 2. 配置 SSH 连接
在本地 `~/.ssh/config` 添加条目（管理员会提供 HostName 与用户名）：
```sshconfig
Host dev-host
  HostName your.server.ip
  User <你的用户名>
  IdentityFile ~/.ssh/id_ed25519
```

测试连接：
```bash
ssh dev-host
```

## 3. VS Code 远程开发
1) 安装扩展：Remote - SSH
2) 命令面板：Remote-SSH: Connect to Host… 选择 `dev-host`
3) 首次连接会自动安装 VS Code Server 到你的家目录

## 4. 首次登录后的环境建议
- Git 基本信息：
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

- 验证访问与权限：
```bash
id
umask
cd /srv/projects/<project>
mkdir -p test && echo ok > test/hello.txt && cat test/hello.txt
```

## 5. 安装开发工具（用户态安装，无需 sudo）
Node.js（nvm 推荐）：
```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install --lts
node -v && npm -v
npm i -g pnpm yarn  # 可选
```

其他：
- Python 可用 `pyenv`
- 多语言统一管理可用 `asdf`

## 6. 端口转发（本地访问远端服务）
```bash
ssh -L 3000:localhost:3000 dev-host
# 在远端跑服务后，本地浏览器访问 http://localhost:3000
```

## 7. 协作规范
- 仅在分配的项目目录（如 `/srv/projects/<project>`）内共享与提交代码
- 私钥严禁外发；如需在多台开发机使用，可将公钥逐台添加到远端账户
- 如需访问新项目目录，联系管理员将你加入对应项目组
- 非必要不使用 sudo；语言与工具尽量用用户态管理器（nvm/pyenv/asdf）

