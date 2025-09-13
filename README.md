# remote-dev-host-manage

管理远程开发主机的实用脚本集合。

- `create_devs_ubuntu.sh`：在 Ubuntu 上批量创建开发者用户，默认禁用密码、配置 SSH、公私目录权限。
- `users.sample.txt`：示例用户清单格式。

## 快速开始

1) 准备用户清单（每行 `username[:ssh_pubkey]`）

```
cp users.sample.txt users.txt
# 编辑 users.txt，按需填写用户名和 SSH 公钥
```

2) 先演练（不改动系统）

```
make dry-run USERS_FILE=users.txt
```

3) 应用创建

```
make apply USERS_FILE=users.txt
```

4) 验证

```
make verify USERS_FILE=users.txt
```

如果不使用 Makefile，也可以直接运行：

```
sudo bash ./create_devs_ubuntu.sh -f users.txt --umask 027 --home-mode 750 [--dry-run]
```

或使用一键脚本：

```
# 演练
DRY_RUN=1 USERS_FILE=users.txt ./provision.sh
# 应用
USERS_FILE=users.txt ./provision.sh
```

## Makefile 目标

- `make dry-run`：演练创建（不落盘）。
- `make apply`：批量创建并配置用户。
- `make verify`：检查用户是否存在与家目录权限。
- `make ssh-harden`：将 `PasswordAuthentication` 设为 `no` 并重载 sshd（谨慎）。
- `make set-dir-mode`：将 `/etc/adduser.conf` 的 `DIR_MODE` 设为 `0750`（影响今后新用户）。
- `make set-umask`：在 `/etc/profile.d/umask_dev.sh` 设定 `umask 027`（对新会话生效）。

可用变量（覆盖默认）：

- `USERS_FILE`（默认：`users.txt`）
- `HOME_MODE`（默认：`750`）
- `UMASK`（默认：`027`）

示例：`make apply USERS_FILE=users.txt HOME_MODE=750 UMASK=027`

## 安全建议

- 默认已禁用密码登录，建议为所有用户配置 SSH 公钥。
- 只为需要的用户赋予 sudo：`sudo usermod -aG sudo USER`。
- 团队共享资源用组管理，避免交叉读写家目录；`HOME_MODE=750` 与 `umask 027` 可以减少误共享。
- 若启用 `ssh-harden` 会禁用口令登录，确保已有可用 SSH 公钥后再执行，避免锁外。

