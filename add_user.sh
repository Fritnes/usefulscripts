#!/bin/bash

# How to use:
#   curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | bash -s -- -u myuser -pw "mypassword" [-s]
#   curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | bash -s -- -u myuser -pkey "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..." [-s]
#   curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | bash -s -- -u myuser [-s]

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u) USERNAME="$2"; shift ;;
        -pkey) PUBKEY="$2"; shift ;;
        -pw) PASSWORD="$2"; shift ;;
        -s) SUDO_FLAG=1 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Check required arguments
if [[ -z "$USERNAME" ]]; then
    echo "Usage: $0 -u username [-pkey \"ssh-rsa ...\" | -pw \"password\"] [-s]"
    exit 1
fi

# If neither key nor password provided → ask for password interactively
if [[ -z "$PUBKEY" && -z "$PASSWORD" ]]; then
    read -s -p "Enter password for $USERNAME: " PASSWORD
    echo
    read -s -p "Confirm password for $USERNAME: " PASSWORD_CONFIRM
    echo
    if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
        echo "Error: passwords do not match"
        exit 1
    fi
fi

# Create user if not exists
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists."
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "User '$USERNAME' created."
fi

# Add to wheel group if -s flag is set
if [[ $SUDO_FLAG -eq 1 ]]; then
    usermod -aG wheel "$USERNAME"
    echo "Added '$USERNAME' to wheel group."
fi

# If public key is provided → setup SSH
if [[ -n "$PUBKEY" ]]; then
    SSH_DIR="/home/$USERNAME/.ssh"
    mkdir -p "$SSH_DIR"
    echo "$PUBKEY" > "$SSH_DIR/authorized_keys"

    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/authorized_keys"
    chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

    echo "Public key installed for '$USERNAME'."
fi

# If password is provided (via -pw or interactive) → set it
if [[ -n "$PASSWORD" ]]; then
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "Password set for '$USERNAME'."
fi
