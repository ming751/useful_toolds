#!/usr/bin/env bash
# Sourcing this library makes no changes.
info() { printf '[信息] %s\n' "$*"; }
die() { printf '[错误] %s\n' "$*" >&2; return 1; }
event() {
    local kind=$1; shift
    printf '[%s] %s\n' "$kind" "$*"
    printf '%s\t%s\t%s\n' "${CURRENT_MODULE:-setup}" "$kind" "$*" >> "$EVENT_FILE"
}
installed() {
    [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true) == 'install ok installed' ]]
}
as_user() {
    sudo -H --preserve-env=http_proxy,https_proxy,all_proxy,no_proxy,HTTP_PROXY,HTTPS_PROXY,ALL_PROXY,NO_PROXY \
        -u "$TARGET_USER" -- "$@"
}
user_command() {
    as_user env PATH="$USER_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/snap/bin" sh -c 'command -v "$1"' sh "$1"
}
check_platform() {
    [[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { die '仅支持 Ubuntu 24.04 x86_64 桌面版'; return 1; }
    # shellcheck source=/dev/null
    source /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || { die '仅支持 Ubuntu 24.04'; return 1; }
    [[ -d /run/systemd/system ]] || { die '需要正常启动的 systemd 系统'; return 1; }
    if grep -qi microsoft /proc/sys/kernel/osrelease || [[ -d /run/casper || -d /rofs ]]; then
        die '不支持 WSL 或 Ubuntu 试用 U 盘，请在已安装的 Ubuntu 桌面运行'; return 1
    fi
}
resolve_user() {
    TARGET_USER=${SUDO_USER:-}
    [[ -n $TARGET_USER && $TARGET_USER != root ]] || { die '请从普通用户账号运行，而不是直接登录 root'; return 1; }
    USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    USER_GROUP=$(id -gn "$TARGET_USER")
    [[ -n $USER_HOME && $USER_HOME != / && -d $USER_HOME ]] || { die '无法确认目标用户 home 目录'; return 1; }
}
init_run() {
    exec 9>/run/useful-toolds.lock
    flock -n 9 || { die '已有安装或 Docker 配置任务运行中'; return 1; }
    RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
    RUN_DIR=$(mktemp -d /tmp/useful-toolds.XXXXXX)
    CACHE_DIR=/var/cache/useful-toolds
    BACKUP_DIR="/var/backups/useful-toolds/$RUN_ID"
    LOG_FILE="/var/log/useful-toolds-$RUN_ID.log"
    EVENT_FILE="$RUN_DIR/events.tsv"
    install -d -m 0755 "$CACHE_DIR"
    install -d -m 0700 "$BACKUP_DIR"
    touch "$EVENT_FILE" "$LOG_FILE"
    chmod 0600 "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    trap 'rm -rf -- "$RUN_DIR"' EXIT
    info "目标用户：$TARGET_USER；日志：$LOG_FILE"
}
backup_file() {
    local path=$1 destination="$BACKUP_DIR$1"
    if [[ -e $path || -L $path ]]; then
        if [[ ! -e $destination && ! -L $destination ]]; then
            mkdir -p -- "$(dirname -- "$destination")"
            cp -a -- "$path" "$destination"
        fi
    fi
}
apt_refresh() {
    if [[ -f $RUN_DIR/apt-failed ]]; then
        die '本次软件源刷新已失败，请修复网络或软件源后重试；不重复刷新'; return 1
    fi
    if [[ ! -f $RUN_DIR/apt-refreshed ]]; then
        if ! apt-get -o DPkg::Lock::Timeout=120 -o Acquire::Retries=2 -o APT::Update::Error-Mode=any update; then
            touch "$RUN_DIR/apt-failed"
            die '软件源刷新失败，请查看上面的网络或 APT 错误'; return 1
        fi
        touch "$RUN_DIR/apt-refreshed"
    fi
}
apt_install() {
    local package
    local -a missing=()
    for package in "$@"; do
        if installed "$package"; then event 已有跳过 "$package"; else missing+=("$package"); fi
    done
    ((${#missing[@]})) || return 0
    apt_refresh
    # Only request absent packages; dependencies needed by new packages may change.
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 --no-remove --no-upgrade install -y "${missing[@]}"
    for package in "${missing[@]}"; do
        installed "$package" || { die "$package 安装未完成"; return 1; }
        event 安装完成 "$package"
    done
}
universe_install() {
    local package need_universe=0
    for package in "$@"; do
        if ! installed "$package"; then
            apt_refresh
            if ! LC_ALL=C apt-cache policy "$package" | grep -Eq 'Candidate: [^ (]'; then need_universe=1; fi
        fi
    done
    if ((need_universe)); then
        apt_install software-properties-common
        backup_file /etc/apt/sources.list
        backup_file /etc/apt/sources.list.d
        add-apt-repository -y -n universe
        rm -f -- "$RUN_DIR/apt-refreshed"
        apt_refresh
    fi
    apt_install "$@"
}
fetch() {
    local url=$1 destination=$2 temporary
    [[ $url == https://* ]] || { die '下载地址必须使用 HTTPS'; return 1; }
    temporary=$(mktemp "$destination.part.XXXXXX")
    info "正在下载：$(basename -- "$destination")"
    if ! curl --fail --location --progress-bar --show-error --retry 2 --connect-timeout 20 --max-time 1800 \
        --proto '=https' --proto-redir '=https' --output "$temporary" "$url"; then
        rm -f -- "$temporary"
        die '下载失败；保留旧缓存，当前模块不会继续安装'; return 1
    fi
    [[ -s $temporary ]] || { rm -f -- "$temporary"; die '下载内容为空'; return 1; }
    chmod 0644 "$temporary"
    mv -f -- "$temporary" "$destination"
}
install_app() {
    local package=$1 command_name=$2 url=$3 path architecture
    if installed "$package"; then event 已有跳过 "$package"; return 0; fi
    if user_command "$command_name" >/dev/null; then
        event 已有跳过 "$command_name 已通过其他方式安装，保留现有安装"; return 0
    fi
    apt_install ca-certificates curl
    path="$CACHE_DIR/$package.deb"
    fetch "$url" "$path"
    [[ $(dpkg-deb -f "$path" Package) == "$package" ]] || { die "$package 下载内容的包名不匹配"; return 1; }
    architecture=$(dpkg-deb -f "$path" Architecture)
    [[ $architecture == amd64 || $architecture == all ]] || { die "$package 下载内容的架构不匹配"; return 1; }
    apt_refresh
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 --no-remove --no-upgrade install -y "$path"
    installed "$package" || { die "$package 安装未完成"; return 1; }
    event 安装完成 "$package"
}
ensure_group() {
    local group=$1
    if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -Fxq "$group"; then
        event 已有跳过 "$TARGET_USER 已属于 $group 组"
    else
        getent group "$group" >/dev/null || groupadd "$group"
        usermod -aG "$group" "$TARGET_USER"
        event 配置补齐 "$group 组权限"
        event 待登录 "重新登录以启用 $group 组权限"
    fi
}
user_config() {
    local helper=$1; shift
    local result
    local -a prefix=()
    if [[ $helper == configure_desktop.py ]]; then prefix=(dbus-run-session --); fi
    result=$(as_user "${prefix[@]}" python3 "$SCRIPT_DIR/helpers/$helper" "$USER_HOME" "$REPO_ROOT/templates" "$RUN_ID" "$@")
    if [[ -n $result ]]; then event 配置补齐 "$result"; else event 已有跳过 "$helper 配置已存在"; fi
}
