#!/bin/bash

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -u) USERNAME="$2"; shift ;;
        -pkey) PUBKEY="$2"; shift ;;
        -pw) PASSWORD="$2"; shift ;;
        -gh) GITHUB_USER="$2"; shift ;;
        -s) SUDO_FLAG=1 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Check required arguments
if [[ -z "$USERNAME" ]]; then
    echo "Usage: $0 -u username [-pkey \"ssh-rsa ...\" | -pw \"password\" | -gh githubuser] [-s]"
    exit 1
fi

# Pull SSH keys from GitHub if requested
if [[ -n "$GITHUB_USER" ]]; then
    echo "Fetching SSH keys from GitHub user '$GITHUB_USER'..."

    PUBKEY=$(curl -fsSL "https://github.com/$GITHUB_USER.keys")

    if [[ -z "$PUBKEY" ]]; then
        echo "Error: no SSH keys found for GitHub user '$GITHUB_USER'"
        exit 1
    fi

    echo "SSH keys fetched successfully."
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

# Add to sudo/wheel group if requested
if [[ $SUDO_FLAG -eq 1 ]]; then
    if getent group wheel >/dev/null; then
        usermod -aG wheel "$USERNAME"
        echo "Added '$USERNAME' to wheel group."
    else
        usermod -aG sudo "$USERNAME"
        echo "Added '$USERNAME' to sudo group."
    fi
fi

# Setup SSH keys
if [[ -n "$PUBKEY" ]]; then
    SSH_DIR="/home/$USERNAME/.ssh"

    mkdir -p "$SSH_DIR"

    echo "$PUBKEY" > "$SSH_DIR/authorized_keys"

    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/authorized_keys"

    chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

    echo "SSH key(s) installed for '$USERNAME'."
fi

# Set password if provided
if [[ -n "$PASSWORD" ]]; then
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "Password set for '$USERNAME'."
fi
