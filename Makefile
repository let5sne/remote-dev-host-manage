.PHONY: help dry-run apply verify ssh-harden set-dir-mode set-umask mk-group mk-workspace assign-group

USERS_FILE ?= users.txt
HOME_MODE ?= 750
UMASK ?= 027

help:
	@echo "Targets:"
	@echo "  make dry-run       # 演练创建（不落盘）"
	@echo "  make apply         # 批量创建并配置用户"
	@echo "  make verify        # 检查用户与家目录权限"
	@echo "  make ssh-harden    # 禁用口令登录并重载 sshd (谨慎)"
	@echo "  make set-dir-mode  # 将 /etc/adduser.conf 的 DIR_MODE 设为 0750"
	@echo "  make set-umask     # 在 /etc/profile.d/umask_dev.sh 设定 umask 027"
	@echo "  make mk-group       # 创建组并把用户加入 (GROUP, USERS)"
	@echo "  make mk-workspace   # 创建共享目录 (WORKSPACE, GROUP, MODE, STICKY)"
	@echo "  make assign-group   # 将 USERS 加入 GROUP"

dry-run:
	sudo bash ./create_devs_ubuntu.sh -f $(USERS_FILE) --home-mode $(HOME_MODE) --umask $(UMASK) --dry-run

apply:
	sudo bash ./create_devs_ubuntu.sh -f $(USERS_FILE) --home-mode $(HOME_MODE) --umask $(UMASK)

verify:
	@set -e; \
	if [ ! -f "$(USERS_FILE)" ]; then echo "Missing $(USERS_FILE)"; exit 1; fi; \
	awk -F: 'NF && $${1}!~/^\s*#/ {print $${1}}' "$(USERS_FILE)" | while read -r u; do \
	  [ -z "$$u" ] && continue; \
	  echo "--- $$u"; \
	  id $$u 2>/dev/null || echo "[WARN] user not found: $$u"; \
	  home=$$(getent passwd $$u | cut -d: -f6); \
	  [ -n "$$home" ] && [ -d "$$home" ] && ls -ld "$$home" || true; \
	done

ssh-harden:
	sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
	sudo systemctl reload ssh || sudo systemctl reload sshd || true
	@echo "PasswordAuthentication set to no; sshd reloaded."

set-dir-mode:
	sudo sed -i 's/^DIR_MODE=.*/DIR_MODE=0750/' /etc/adduser.conf
	@echo "Updated /etc/adduser.conf: DIR_MODE=0750 (affects future users)."

set-umask:
	echo 'umask $(UMASK)' | sudo tee /etc/profile.d/umask_dev.sh >/dev/null
	sudo chmod 644 /etc/profile.d/umask_dev.sh
	@echo "Set system umask to $(UMASK) for new sessions."

# Directory and group helpers
GROUP ?=
USERS ?=
WORKSPACE ?=
MODE ?= 2770
STICKY ?= 0

mk-group:
	@if [ -z "$(GROUP)" ]; then echo "Usage: make mk-group GROUP=proj-alpha USERS=alice,bob"; exit 2; fi
	sudo bash ./setup_dirs_ubuntu.sh --group "$(GROUP)" --path /tmp/.noop --dry-run >/dev/null || true
	@if getent group "$(GROUP)" >/dev/null; then echo "[OK] Group exists: $(GROUP)"; else sudo groupadd "$(GROUP)"; fi
	@if [ -n "$(USERS)" ]; then IFS=,; for u in $(USERS); do echo "[ADD] $$u -> $(GROUP)"; sudo usermod -aG "$(GROUP)" "$$u" || true; done; fi

mk-workspace:
	@if [ -z "$(GROUP)" ] || [ -z "$(WORKSPACE)" ]; then echo "Usage: make mk-workspace GROUP=proj-alpha WORKSPACE=/srv/projects/alpha [MODE=2770] [STICKY=1]"; exit 2; fi
	@if [ "$(STICKY)" = "1" ]; then SFLAG=--sticky; else SFLAG=; fi; \
		sudo bash ./setup_dirs_ubuntu.sh --group "$(GROUP)" --path "$(WORKSPACE)" --mode "$(MODE)" $$SFLAG

assign-group:
	@if [ -z "$(GROUP)" ] || [ -z "$(USERS)" ]; then echo "Usage: make assign-group GROUP=proj-alpha USERS=alice,bob"; exit 2; fi
	@IFS=,; for u in $(USERS); do echo "[ADD] $$u -> $(GROUP)"; sudo usermod -aG "$(GROUP)" "$$u"; done
