#!/usr/bin/env bash

# How to use:
#   curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/first_install.sh | bash

set -euo pipefail

# Vars
ALLOW_SSH_PASSWORD="false"

# --- Ensure wheel group ---
if ! getent group wheel >/dev/null; then
    groupadd wheel
fi

# --- Allow wheel group passwordless sudo ---
if ! grep -q '^%wheel' /etc/sudoers; then
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
else
    sed -i 's|^%wheel.*|%wheel ALL=(ALL) NOPASSWD: ALL|' /etc/sudoers
fi
visudo -cf /etc/sudoers || { echo "Invalid sudoers file!"; exit 1; }

# --- SSHD hardening ---
sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config || echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

if [[ "$ALLOW_SSH_PASSWORD" != "true" ]]; then
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
fi

systemctl restart sshd

# --- Custom root prompt ---
ROOT_BASHRC="/root/.bashrc"

if ! grep -q "Custom PS1 prompt" "$ROOT_BASHRC" 2>/dev/null; then
    cat <<'EOF' >> "$ROOT_BASHRC"

# --- Custom PS1 prompt ---
if [ "\$(id -un)" = root ]; then
  PS1="[\[$(tput sgr0)\]\[\033[38;5;6m\]\A\[$(tput sgr0)\]][\[$(tput sgr0)\]\[\033[38;5;9m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[\033[38;5;6m\]\h\[$(tput sgr0)\]]:\[$(tput sgr0)\]\[\033[38;5;203m\]\W\[$(tput sgr0)\]\\$ \[$(tput sgr0)\]"
else
  PS1="[\[$(tput sgr0)\]\[\033[38;5;6m\]\A\[$(tput sgr0)\]][\[$(tput sgr0)\]\[\033[38;5;6m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[\033[38;5;6m\]\h\[$(tput sgr0)\]]:\[$(tput sgr0)\]\[\033[38;5;203m\]\W\[$(tput sgr0)\]\\$ \[$(tput sgr0)\]"
fi
# --- End custom PS1 prompt ---
EOF
fi
