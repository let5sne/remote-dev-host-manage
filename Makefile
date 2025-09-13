.PHONY: help dry-run apply verify ssh-harden set-dir-mode set-umask

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

