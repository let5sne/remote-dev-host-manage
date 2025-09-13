# 新开发者入职流程（管理员）

适用环境：Ubuntu 22.04。仓库路径：`/root/remote-dev-host-manage`。

## 1. 前置准备
- 收集信息：
  - 用户名（小写、字母数字与`-_`）
  - 开发者 SSH 公钥（建议由开发者本地生成）
  - 所属项目名（如 `alpha`）
- 确认已拉取本仓库并在根目录执行命令：
  - `cd /root/remote-dev-host-manage`

## 2. 安装依赖（一次性）
用于项目目录默认权限继承与 ACL：
```bash
make deps   # 安装 acl (setfacl)
```

## 3. 创建用户账号（禁用密码、安装公钥）
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

## 4. 分配项目组与共享目录
为项目创建组、把用户加入，并创建共享工作区：
```bash
PROJECT=alpha
make mk-group GROUP=proj-$PROJECT USERS=$USER
make mk-workspace GROUP=proj-$PROJECT WORKSPACE=/srv/projects/$PROJECT MODE=2770 STICKY=0
```

验证写权限：
```bash
sudo -u "$USER" test -w "/srv/projects/$PROJECT" && echo OK || echo FAIL
```

## 5. 向开发者发放连接信息
- 提供：主机 IP/域名、端口（如非 22）、分配的用户名
- 客户端示例（让开发者写入其本地 `~/.ssh/config`）：
```sshconfig
Host dev-host
  HostName your.server.ip
  Port 22                # 若改端口，请同步更新，如 2222
  User alice
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes     # 仅使用该私钥，避免因密钥过多导致连接失败
  ServerAliveInterval 30 # 30 秒保活，弱网更稳
  ServerAliveCountMax 3  # 连续 3 次失败后断开
  Compression yes        # 弱网下略降延迟（CPU 换带宽）
  ControlMaster auto     # 复用 SSH 连接，提高 VS Code 多通道性能
  ControlPersist 5m
  ControlPath ~/.ssh/cm-%r@%h:%p
  # StrictHostKeyChecking ask  # 首次连接提示确认主机指纹（更安全可开启）
```

说明：
- `Port`：如你在服务端将 SSH 改为非 22 端口（见下文），需在此同步设置。
- `IdentitiesOnly yes`：避免 ssh-agent 提供过多密钥导致“Too many authentication failures”。
- `ServerAlive*`：客户端保活，弱网/长连接更稳定。
- `ControlMaster/ControlPersist`：复用连接，VS Code Remote-SSH 更流畅。

## 6. 可选安全加固（全员密钥可登录后再做）
```bash
make ssh-harden      # 禁用口令登录，reload sshd
make set-dir-mode    # 将新建用户家目录默认设为 0750（影响未来用户）
make set-umask       # 系统会话默认 umask 027（更少组外可读）
```

### sshd 服务端推荐配置（/etc/ssh/sshd_config）
- 变更前请务必保持一个已登录的 root/sudo 会话以防锁死；修改后 `sudo systemctl reload ssh`。
```conf
# 端口与登录策略
Port 22                       # 如需改端口先放行防火墙再改：示例 2222
PermitRootLogin no            # 禁止 root 直登
PasswordAuthentication no     # 仅允许密钥登录（make ssh-harden 已设置）
MaxAuthTries 3                # 限制连续认证失败次数
LoginGraceTime 30             # 登录宽限时间（秒）

# 组/用户准入（可选：限制到指定组或用户）
# AllowGroups devs proj-alpha proj-beta
# 或：AllowUsers alice bob

# 会话与保活（服务器侧）
ClientAliveInterval 180
ClientAliveCountMax 3

# 其他
UseDNS no                     # 避免反查延迟
X11Forwarding no              # 默认关闭，减少攻击面
```

如需变更端口示例（以 2222 为例）：
```bash
sudo ufw allow 2222/tcp            # 或相应防火墙规则
sudo sed -i 's/^#\?Port .*/Port 2222/' /etc/ssh/sshd_config
sudo systemctl reload ssh
```

## 7. 日常运维
- 新增成员到项目：
```bash
make assign-group GROUP=proj-alpha USERS=bob
```
- 新增项目空间：
```bash
make mk-workspace GROUP=proj-beta PATH=/srv/projects/beta MODE=2770
```

## 8. 离职/禁用
```bash
passwd -l alice                          # 立即禁用登录
gpasswd -d alice proj-alpha              # 移出项目组
tar czf /root/archive/alice.tgz /home/alice  # 归档家目录（可选）
userdel -r alice                         # 删除用户与家目录（谨慎）
```

## 9. 故障排查速查
### 错误：`setfacl: command not found`
未安装 `acl` 软件包。执行：
```bash
make deps
```
- 无法写项目目录：检查是否在组内 `id alice`，目录属组/权限 `ls -ld /srv/projects/alpha`
- SSH 仍提示口令：确认公钥写入 `~alice/.ssh/authorized_keys` 且权限 600/700
- 口令登录被禁用：如已 `ssh-harden`，需确保公钥正常后再执行该步骤
