#!/bin/bash

set -euo pipefail

CONFIG_DIR="/etc/docker"
CONFIG_FILE="${CONFIG_DIR}/daemon.json"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] 请使用 sudo 运行此脚本: sudo ./scripts/docker/configure_daemon.sh"
  exit 1
fi

mkdir -p "${CONFIG_DIR}"

if [ -f "${CONFIG_FILE}" ]; then
  BACKUP_FILE="${CONFIG_FILE}.bak.${TIMESTAMP}"
  cp "${CONFIG_FILE}" "${BACKUP_FILE}"
  echo "[INFO] 已备份现有配置到: ${BACKUP_FILE}"
fi

cat > "${CONFIG_FILE}" <<'EOF'
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

echo "[INFO] 已写入 ${CONFIG_FILE}"

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl restart docker
  echo "[INFO] Docker 服务已重启"
else
  echo "[WARN] 未检测到 systemctl，请手动重启 Docker 服务"
fi

echo "[INFO] 可使用以下命令验证配置:"
echo "docker info"
