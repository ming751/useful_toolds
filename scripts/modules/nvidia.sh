#!/usr/bin/env bash
nvidia_driver_installed() {
    dpkg-query -W -f='${Package} ${Status}\n' 'nvidia-driver-*' 2>/dev/null | grep -Eq '^nvidia-driver-[^ ]+ install ok installed$'
}
module_nvidia() {
    apt_install pciutils
    if ! lspci -nn | grep -Eiq '(VGA|3D|Display).*\[10de:'; then
        event 已有跳过 '没有 NVIDIA 显卡，无需驱动'; return 0
    fi
    if command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
        event 已有跳过 'NVIDIA 驱动正常工作'; return 0
    fi
    if nvidia_driver_installed; then
        event 已有跳过 'NVIDIA 驱动软件包已安装'
        event 待操作 '驱动尚不可用：请重启并完成可能的 Secure Boot/MOK 操作；仍失败时检查 nvidia-smi，不重复安装'
        return 0
    fi
    universe_install ubuntu-drivers-common
    apt_refresh
    DEBIAN_FRONTEND=readline ubuntu-drivers install
    nvidia_driver_installed || { die '未检测到已安装的 NVIDIA 驱动，请检查 ubuntu-drivers 输出'; return 1; }
    event 安装完成 'Ubuntu 推荐 NVIDIA 驱动'
    event 待重启 '重启后用 nvidia-smi 检查显卡；若系统要求注册 MOK，请在重启界面完成'
}
