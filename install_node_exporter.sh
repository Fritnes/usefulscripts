#!/bin/bash

set -e

# === Parse CLI Argument ===
if [[ -n "$1" ]]; then
    if [[ "$1" = /* ]]; then
        BASE_DIR="$1"
    else
        echo "[ERROR] BASE_DIR must be an absolute path"
        exit 1
    fi
else
    BASE_DIR="/opt/monitoring_tools"
fi

EXPORTER_DIR="${BASE_DIR}/node_exporter"
BIN_NAME="node_exporter"
BIN_PATH="${EXPORTER_DIR}/${BIN_NAME}"
SERVICE_NAME="node_exporter"
GITHUB_API_URL="https://api.github.com/repos/prometheus/node_exporter/releases/latest"

# === Detect Architecture ===
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_TAG="linux-amd64"
        ;;
    aarch64)
        ARCH_TAG="linux-arm64"
        ;;
    armv7l)
        ARCH_TAG="linux-armv7"
        ;;
    *)
        echo "[ERROR] Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "[INFO] Using base directory: $BASE_DIR"
echo "[INFO] Architecture: $ARCH → Release: $ARCH_TAG"

# === Create Exporter Directory ===
if [[ -d "$EXPORTER_DIR" ]]; then
    echo "[INFO] Directory $EXPORTER_DIR already exists."
else
    echo "[INFO] Creating exporter directory at $EXPORTER_DIR..."
    mkdir -p "$EXPORTER_DIR"
fi

# === Fetch Latest Version ===
echo "[INFO] Checking latest node_exporter version..."
LATEST_VERSION=$(curl -s "$GITHUB_API_URL" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
echo "[INFO] Latest version: v$LATEST_VERSION"

# === Check Existing Installation ===
if [[ -x "$BIN_PATH" ]]; then
    INSTALLED_VERSION=$("$BIN_PATH" --version 2>&1 | head -n1 | awk '{print $3}')
    echo "[INFO] Installed version: $INSTALLED_VERSION"
else
    echo "[INFO] No existing installation found in $EXPORTER_DIR."
    INSTALLED_VERSION=""
fi

# === Download and Install if Needed ===
if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]; then
    echo "[INFO] Latest version is already installed."
else
    echo "[INFO] Installing node_exporter v$LATEST_VERSION..."

    ARCHIVE="node_exporter-${LATEST_VERSION}.${ARCH_TAG}.tar.gz"
    URL="https://github.com/prometheus/node_exporter/releases/download/v${LATEST_VERSION}/${ARCHIVE}"

    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    echo "[INFO] Downloading $URL..."
    curl -sLO "$URL"

    echo "[INFO] Extracting..."
    tar -xzf "$ARCHIVE"

    echo "[INFO] Installing binary to $BIN_PATH..."
    cp "node_exporter-${LATEST_VERSION}.${ARCH_TAG}/node_exporter" "$BIN_PATH"
    chmod +x "$BIN_PATH"

    cd -
    rm -rf "$TMP_DIR"
fi

# === Create systemd service ===
echo "[INFO] Writing systemd service..."

tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=${BIN_PATH} --collector.textfile.directory=${EXPORTER_DIR}/textfile_collector

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}

echo "[SUCCESS] node_exporter v${LATEST_VERSION} installed and running from $BIN_PATH"
