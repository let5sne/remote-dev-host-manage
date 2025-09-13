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
- `make mk-group`：创建组并把用户加入（需传 `GROUP`、可选 `USERS`）。
- `make mk-workspace`：创建共享目录并设置继承与 ACL（需传 `GROUP`、`PATH`，可选 `MODE`、`STICKY`）。
- `make assign-group`：将 `USERS` 批量加入 `GROUP`。

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

## 目录与权限分配建议

- 个人目录：`/home/<user>` 设置为 `750`，默认 `umask 027`，避免用户间互读。
- 项目组：为每个项目或团队建立 Unix 组（如 `proj-alpha`），将相关开发者加入该组。
- 工作区布局（示例）：
  - `/srv/projects/alpha`（组 `proj-alpha`，模式 `2770`，setgid 继承组）
  - `setfacl` 设定默认 ACL：组拥有 `rwx`，新建文件/目录自动继承
  - 可选加 sticky 位（`+t`）限制互删：使用 `STICKY=1` 或脚本 `--sticky`
- 共享只读区：`/srv/public`（`755`），供全员读取发布资料。
- 共享临时区：`/srv/scratch`（`1777`，类似 `/tmp`），允许临时文件但防互删。

命令示例（alpha 项目）：

```
sudo groupadd proj-alpha
sudo usermod -aG proj-alpha alice
sudo usermod -aG proj-alpha bob
sudo install -d -m 2770 -o root -g proj-alpha /srv/projects/alpha
sudo setfacl -R -m g:proj-alpha:rwx /srv/projects/alpha
sudo setfacl -R -m d:g:proj-alpha:rwx /srv/projects/alpha
```

或使用提供的脚本与 Make 目标：

```
# 建组并加人
make mk-group GROUP=proj-alpha USERS=alice,bob
# 建工作区（可选 STICKY=1）
make mk-workspace GROUP=proj-alpha PATH=/srv/projects/alpha MODE=2770 STICKY=0
```
