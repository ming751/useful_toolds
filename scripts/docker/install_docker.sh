#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO] $*${NC}"
}

log_step() {
  echo -e "${GREEN}[STEP] $*${NC}"
}

log_warn() {
  echo -e "${YELLOW}[WARN] $*${NC}"
}

log_error() {
  echo -e "${RED}[ERROR] $*${NC}"
}

if [ "${EUID}" -ne 0 ]; then
  log_error "请使用 sudo 运行此脚本: sudo ./scripts/docker/install_docker.sh"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log_error "当前系统不支持 apt-get，此脚本仅适用于 Debian/Ubuntu 系。"
  exit 1
fi

if [ -z "${SUDO_USER:-}" ] || [ "${SUDO_USER}" = "root" ]; then
  log_error "请从要配置的普通用户账号执行 sudo，再运行此脚本。"
  exit 1
fi

REAL_USER="${SUDO_USER}"
USER_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"

if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
  log_error "无法定位用户 ${REAL_USER} 的 home 目录。"
  exit 1
fi

log_step "安装 Docker"
log_info "目标用户: ${REAL_USER} (Home: ${USER_HOME})"

apt-get update -y

if command -v docker >/dev/null 2>&1; then
  log_info "Docker 已安装，跳过 docker.io 安装。"
else
  apt-get install -y docker.io
  log_info "Docker 安装完成。"
fi

if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
  apt-get install -y docker-compose-plugin
  log_info "docker-compose-plugin 安装完成。"
else
  log_warn "当前软件源没有 docker-compose-plugin，已跳过。"
fi

if ! getent group docker >/dev/null 2>&1; then
  groupadd docker
  log_info "已创建 docker 用户组。"
fi

if id -nG "${REAL_USER}" | tr ' ' '\n' | grep -qx docker; then
  log_info "用户 ${REAL_USER} 已在 docker 组中。"
else
  usermod -aG docker "${REAL_USER}"
  log_info "已将用户 ${REAL_USER} 加入 docker 组，重新登录后生效。"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable docker >/dev/null 2>&1 || log_warn "Docker 开机自启设置失败，请手动检查。"
  systemctl restart docker >/dev/null 2>&1 || log_warn "Docker 重启失败，请手动检查服务状态。"
else
  log_warn "未检测到 systemctl，请手动启动 Docker 服务。"
fi

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Docker 安装与基础配置已完成。${NC}"
echo -e "${GREEN}  1. 请注销并重新登录，以启用 docker 组权限。${NC}"
echo -e "${GREEN}  2. 可执行 'docker --version' 检查 Docker。${NC}"
echo -e "${GREEN}  3. 可执行 'docker compose version' 检查 Compose 插件。${NC}"
echo -e "${GREEN}  4. 建议继续执行 'sudo ./scripts/docker/configure_daemon.sh' 配置镜像加速。${NC}"
echo -e "${GREEN}  5. 可执行 'docker run hello-world' 做最终验证。${NC}"
echo -e "${GREEN}==========================================${NC}"
