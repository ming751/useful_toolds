#!/bin/bash

set -euo pipefail

# ==========================================
# Linux 机器人开发环境一键配置脚本
# 包含: C++工具链, Zsh, Git, CUDA, Docker, NVIDIA Container Toolkit
# 说明: ROS 2 安装段当前保留为注释模板，默认不会执行
# ==========================================

# --- 配置参数 ---
SCRIPT_TMP_DIR="/tmp"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# 定义颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. 权限与用户检查
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] 请使用 sudo 运行此脚本 (sudo ./scripts/setup_linux.sh)${NC}"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] 当前系统不支持 apt-get，此脚本仅适用于 Debian/Ubuntu 系。${NC}"
  exit 1
fi

if [ -z "${SUDO_USER:-}" ] || [ "${SUDO_USER}" = "root" ]; then
  echo -e "${RED}[ERROR] 请从普通用户账号执行 sudo，再运行此脚本。${NC}"
  exit 1
fi

REAL_USER="${SUDO_USER}"
USER_HOME=$(getent passwd "${REAL_USER}" | cut -d: -f6)
if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
  echo -e "${RED}[ERROR] 无法定位用户 ${REAL_USER} 的 home 目录。${NC}"
  exit 1
fi

echo -e "${BLUE}[INFO] 目标用户: ${REAL_USER} (Home: ${USER_HOME})${NC}"

# ==========================================
# Part 1: 基础 C++ 与 系统工具
# ==========================================
echo -e "${GREEN}[STEP 1/7] 安装基础开发工具...${NC}"
apt-get update -y
# 增加了 ninja-build (构建加速), ccache (编译缓存), tmux (终端复用), htop
apt-get install -y git curl wget vim build-essential cmake gdb unzip zip tree htop \
    clangd clang-format ninja-build ccache tmux \
    python3-pip python3-dev

# 配置 pip 镜像 (可选，国内建议开启)
# sudo -u $REAL_USER pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# 安装 Python 常用库 (机器人算法常用)
echo -e "${BLUE}  - 安装 Python 科学计算库 (numpy, matplotlib)...${NC}"
sudo -u $REAL_USER pip3 install numpy matplotlib scipy

# ==========================================
# Part 2: Zsh 与 Shell 环境
# ==========================================
echo -e "${GREEN}[STEP 2/7] 调用独立脚本配置 Zsh...${NC}"
bash "${SCRIPT_DIR}/shell/setup_zsh.sh"

# ==========================================
# Part 3: Docker 安装 (新增)
# ==========================================
echo -e "${GREEN}[STEP 3/7] 调用独立脚本安装 Docker...${NC}"
bash "${SCRIPT_DIR}/docker/install_docker.sh"

# ==========================================
# Part 4: CUDA 配置 (用户指定)
# ==========================================
echo -e "${GREEN}[STEP 4/7] 配置 CUDA (Auromix Script)...${NC}"
# 注意：这里切换到用户身份执行，确保环境变量正确，或者直接以 root 执行但注意路径
# Auromix 脚本通常需要 sudo 权限，当前已经是 root，直接运行即可

SCRIPT_NAME="config_cuda.sh"
FULL_SCRIPT_PATH="${SCRIPT_TMP_DIR}/${SCRIPT_NAME}"
DOWNLOAD_URL="https://raw.githubusercontent.com/auromix/ros-install-one-click/main"

wget -O $FULL_SCRIPT_PATH $DOWNLOAD_URL/$SCRIPT_NAME
chmod +x $FULL_SCRIPT_PATH
# 交互式脚本可能需要用户输入，这里直接调用
bash $FULL_SCRIPT_PATH
rm -rf $FULL_SCRIPT_PATH

# ==========================================
# Part 5: NVIDIA Docker Toolkit (强烈推荐)
# ==========================================
echo -e "${GREEN}[STEP 5/7] 配置 NVIDIA Container Toolkit (让Docker能用显卡)...${NC}"
# 只有装了 Docker 和 CUDA 后才需要这个
if command -v docker &> /dev/null; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    apt-get update
    apt-get install -y nvidia-container-toolkit
    # 配置 Docker runtime
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker || echo -e "${YELLOW}Warning: Docker 重启失败 (如果是 WSL 请忽略 systemctl)${NC}"
fi

# # ==========================================
# # Part 6: ROS 2 Humble 安装 (用户指定)
# # ==========================================
# echo -e "${GREEN}[STEP 6/7] 安装 ROS 2 Humble...${NC}"
# ROS_INSTALL_SCRIPT="$USER_HOME/ros2_humble_install.sh"

# # 使用 sudo -u 让 wget 把文件下载到用户目录，而不是 root 目录
# sudo -u $REAL_USER wget -O $ROS_INSTALL_SCRIPT https://raw.githubusercontent.com/auromix/ros-install-one-click/main/ros2_humble_install.sh
# chmod +x $ROS_INSTALL_SCRIPT
# # 运行安装脚本
# bash $ROS_INSTALL_SCRIPT
# rm $ROS_INSTALL_SCRIPT

# # 自动 source ros 环境到 zshrc
# if ! grep -q "source /opt/ros/humble/setup.zsh" "$USER_HOME/.zshrc"; then
#     echo "source /opt/ros/humble/setup.zsh" >> "$USER_HOME/.zshrc"
#     echo -e "${BLUE}  - 已将 ROS 2 source 命令添加到 .zshrc${NC}"
# fi

# ==========================================
# Part 7: 测试与验证
# ==========================================
echo -e "${GREEN}[STEP 7/7] 运行 CUDA/Torch 测试...${NC}"
# 下载测试脚本到用户目录
TEST_SCRIPT="$USER_HOME/test_cuda.py"
sudo -u $REAL_USER wget -O $TEST_SCRIPT https://raw.githubusercontent.com/auromix/ros-install-one-click/main/test_cuda.py

echo -e "${YELLOW}正在运行 Python CUDA 测试...${NC}"
# 尝试运行测试 (如果环境没准备好可能会报错，不影响脚本完成)
python3 $TEST_SCRIPT || echo -e "${RED}测试运行失败 (可能是 torch 尚未安装，请手动安装 torch 后重试)${NC}"

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  🎉 所有配置已完成! ${NC}"
echo -e "${GREEN}  1. 请注销并重新登录以启用 Docker 权限和 Zsh。${NC}"
echo -e "${GREEN}  2. 测试 Docker: 'docker run hello-world'。${NC}"
echo -e "${GREEN}  3. 建议继续执行: 'sudo ./scripts/docker/configure_daemon.sh' 配置镜像加速。${NC}"
echo -e "${GREEN}  4. 如果后续启用 ROS 2 安装段，再单独验证 'ros2' 命令。${NC}"
echo -e "${GREEN}==========================================${NC}"
