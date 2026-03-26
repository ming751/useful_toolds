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

run_as_user() {
  sudo -H -u "${REAL_USER}" env HOME="${USER_HOME}" "$@"
}

ensure_zsh_plugins() {
  local plugins_line=""
  local plugin
  local new_line=""
  local current_plugins=()
  local merged_plugins=()

  if grep -Eq '^[[:space:]]*plugins=' "${ZSHRC_FILE}"; then
    plugins_line="$(grep -E '^[[:space:]]*plugins=' "${ZSHRC_FILE}" | head -n 1)"
    plugins_line="${plugins_line#*=}"
    plugins_line="${plugins_line#*(}"
    plugins_line="${plugins_line%)}"
    read -r -a current_plugins <<< "${plugins_line}"
    merged_plugins=("${current_plugins[@]}")
  fi

  for plugin in git zsh-autosuggestions zsh-syntax-highlighting; do
    if ! printf '%s\n' "${merged_plugins[@]}" | grep -qx "${plugin}"; then
      merged_plugins+=("${plugin}")
    fi
  done

  new_line="plugins=(${merged_plugins[*]})"

  if grep -Eq '^[[:space:]]*plugins=' "${ZSHRC_FILE}"; then
    run_as_user sed -i "0,/^[[:space:]]*plugins=.*/s//${new_line}/" "${ZSHRC_FILE}"
  else
    run_as_user sh -c 'printf "\n%s\n" "$2" >> "$1"' sh "${ZSHRC_FILE}" "${new_line}"
  fi
}

if [ "${EUID}" -ne 0 ]; then
  log_error "请使用 sudo 运行此脚本: sudo ./scripts/shell/setup_zsh.sh"
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

OMZ_DIR="${USER_HOME}/.oh-my-zsh"
ZSHRC_FILE="${USER_HOME}/.zshrc"
ZSH_CUSTOM="${OMZ_DIR}/custom"

log_step "安装并配置 Zsh 环境"
log_info "目标用户: ${REAL_USER} (Home: ${USER_HOME})"

apt-get update -y
apt-get install -y zsh git curl ca-certificates

TARGET_ZSH="$(command -v zsh || echo /bin/zsh)"

if [ ! -d "${OMZ_DIR}" ]; then
  log_info "安装 Oh My Zsh..."
  sudo -H -u "${REAL_USER}" env HOME="${USER_HOME}" RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  log_info "Oh My Zsh 已存在，跳过安装。"
fi

run_as_user mkdir -p "${ZSH_CUSTOM}/plugins"

if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]; then
  log_info "安装 zsh-autosuggestions"
  run_as_user git clone https://github.com/zsh-users/zsh-autosuggestions \
    "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
else
  log_info "zsh-autosuggestions 已安装，跳过。"
fi

if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]; then
  log_info "安装 zsh-syntax-highlighting"
  run_as_user git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
else
  log_info "zsh-syntax-highlighting 已安装，跳过。"
fi

if [ ! -f "${ZSHRC_FILE}" ] && [ -f "${OMZ_DIR}/templates/zshrc.zsh-template" ]; then
  run_as_user cp "${OMZ_DIR}/templates/zshrc.zsh-template" "${ZSHRC_FILE}"
fi

if [ ! -f "${ZSHRC_FILE}" ]; then
  run_as_user sh -c 'cat > "$1" <<EOF
export ZSH="$2"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh
EOF' sh "${ZSHRC_FILE}" "${OMZ_DIR}"
fi

ensure_zsh_plugins

if [ ! -s "${ZSHRC_FILE}" ]; then
  log_warn ".zshrc 为空，建议手动检查 ${ZSHRC_FILE}"
fi

CURRENT_SHELL="$(getent passwd "${REAL_USER}" | cut -d: -f7)"
if [ "${CURRENT_SHELL}" != "${TARGET_ZSH}" ]; then
  chsh -s "${TARGET_ZSH}" "${REAL_USER}"
  log_info "已将默认 shell 设置为 ${TARGET_ZSH}"
else
  log_info "默认 shell 已经是 ${TARGET_ZSH}"
fi

if [ -d "${OMZ_DIR}" ]; then
  chown -R "${REAL_USER}:${REAL_USER}" "${OMZ_DIR}"
fi

if [ -f "${ZSHRC_FILE}" ]; then
  chown "${REAL_USER}:${REAL_USER}" "${ZSHRC_FILE}"
fi

log_info "Zsh 环境配置完成。"
echo -e "${GREEN}  1. 常用插件已启用: git zsh-autosuggestions zsh-syntax-highlighting${NC}"
echo -e "${GREEN}  2. 请重新登录终端，或执行 'exec zsh' 使默认 shell 生效。${NC}"
