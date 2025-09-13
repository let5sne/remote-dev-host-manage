# 新开发者入职流程（管理员）

适用环境：Ubuntu 22.04。仓库路径：`/root/remote-dev-host-manage`。

## 1. 前置准备
- 收集信息：
  - 用户名（小写、字母数字与`-_`）
  - 开发者 SSH 公钥（建议由开发者本地生成）
  - 所属项目名（如 `alpha`）
- 确认已拉取本仓库并在根目录执行命令：
  - `cd /root/remote-dev-host-manage`

## 2. 创建用户账号（禁用密码、安装公钥）
单人创建示例：
```bash
USER=alice
PUBKEY='ssh-ed25519 AAAA... alice@laptop'
printf "%s:%s\n" "$USER" "$PUBKEY" > users.txt
sudo bash ./create_devs_ubuntu.sh -f users.txt
```

批量创建（编辑 `users.txt`，每行 `username[:ssh_pubkey]`）：
```bash
make dry-run USERS_FILE=users.txt   # 不落盘演练
make apply   USERS_FILE=users.txt   # 实际创建
```

验证：
```bash
id alice
ls -ld ~alice
```

## 3. 分配项目组与共享目录
为项目创建组、把用户加入，并创建共享工作区：
```bash
PROJECT=alpha
make mk-group GROUP=proj-$PROJECT USERS=$USER
make mk-workspace GROUP=proj-$PROJECT PATH=/srv/projects/$PROJECT MODE=2770 STICKY=0
```

验证写权限：
```bash
sudo -u "$USER" test -w "/srv/projects/$PROJECT" && echo OK || echo FAIL
```

## 4. 向开发者发放连接信息
- 提供：主机 IP/域名、分配的用户名
- 建议示例（让开发者写入其本地 `~/.ssh/config`）：
```sshconfig
Host dev-host
  HostName your.server.ip
  User alice
  IdentityFile ~/.ssh/id_ed25519
```

## 5. 可选安全加固（全员密钥可登录后再做）
```bash
make ssh-harden      # 禁用口令登录，reload sshd
make set-dir-mode    # 将新建用户家目录默认设为 0750（影响未来用户）
make set-umask       # 系统会话默认 umask 027（更少组外可读）
```

## 6. 日常运维
- 新增成员到项目：
```bash
make assign-group GROUP=proj-alpha USERS=bob
```
- 新增项目空间：
```bash
make mk-workspace GROUP=proj-beta PATH=/srv/projects/beta MODE=2770
```

## 7. 离职/禁用
```bash
passwd -l alice                          # 立即禁用登录
gpasswd -d alice proj-alpha              # 移出项目组
tar czf /root/archive/alice.tgz /home/alice  # 归档家目录（可选）
userdel -r alice                         # 删除用户与家目录（谨慎）
```

## 8. 故障排查速查
- 无法写项目目录：检查是否在组内 `id alice`，目录属组/权限 `ls -ld /srv/projects/alpha`
- SSH 仍提示口令：确认公钥写入 `~alice/.ssh/authorized_keys` 且权限 600/700
- 口令登录被禁用：如已 `ssh-harden`，需确保公钥正常后再执行该步骤

