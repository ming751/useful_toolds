#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

apply_daemon_config() {
    local config=$1; shift
    local -a mirrors=("$@")
    CURRENT_MODULE=docker-config
    mkdir -p -- "$(dirname -- "$config")"
    DAEMON_CANDIDATE=$(mktemp "$(dirname -- "$config")/.daemon.XXXXXX")
    trap 'rm -f -- "${DAEMON_CANDIDATE:-}"; rm -rf -- "$RUN_DIR"' EXIT
    python3 "$SCRIPT_DIR/helpers/docker_config.py" "$config" --output "$DAEMON_CANDIDATE" "${mirrors[@]}"
    if [[ -f $config ]] && cmp -s "$config" "$DAEMON_CANDIDATE"; then
        event 已有跳过 'Docker 配置已满足要求，不重启服务'; return 0
    fi
    dockerd --validate --config-file "$DAEMON_CANDIDATE"
    backup_file "$config"
    if [[ -f $config ]]; then
        chmod --reference="$config" "$DAEMON_CANDIDATE"
        chown --reference="$config" "$DAEMON_CANDIDATE"
    else chmod 0644 "$DAEMON_CANDIDATE"; fi
    mv -f -- "$DAEMON_CANDIDATE" "$config"
    if ! systemctl restart docker; then
        if [[ -f $BACKUP_DIR$config ]]; then
            cp -p -- "$BACKUP_DIR$config" "$DAEMON_CANDIDATE"
            mv -f -- "$DAEMON_CANDIDATE" "$config"
        else rm -f -- "$config"; fi
        systemctl restart docker || info '恢复配置后服务仍未启动，请检查 journalctl -u docker'
        die "Docker 重启失败，原配置已恢复；日志：$LOG_FILE"; return 1
    fi
    event 配置补齐 'Docker 配置已合并并重启服务'
    info "备份：$BACKUP_DIR；使用 docker info 查看结果"
}

main() {
    local dry_run=0 arg
    local -a original_args=("$@") mirrors=()
    while (($#)); do
        arg=$1; shift
        case $arg in
            --help|-h) printf '用法：bash scripts/docker/configure_daemon.sh [--mirror https://镜像地址] [--dry-run]\n保留已有配置，补充缺失的日志轮转配置；--mirror 可重复提供。\n'; return 0 ;;
            --dry-run) dry_run=1 ;;
            --mirror) (($#)) && [[ -n $1 && $1 != --* ]] || { die '--mirror 缺少地址'; return 1; }; mirrors+=(--mirror "$1"); shift ;;
            *) die "未知参数：$arg"; return 1 ;;
        esac
    done
    local config=/etc/docker/daemon.json
    if ((dry_run)); then
        python3 "$SCRIPT_DIR/helpers/docker_config.py" "$config" "${mirrors[@]}"
        info '仅预览合并结果，没有修改配置或重启服务。'
        return 0
    fi
    check_platform
    if ((EUID != 0)); then exec sudo bash "$SCRIPT_DIR/docker/configure_daemon.sh" "${original_args[@]}"; fi
    resolve_user
    command -v dockerd >/dev/null || { die '请先安装 Docker Engine'; return 1; }
    command -v python3 >/dev/null || { die '需要 python3 合并 JSON'; return 1; }
    [[ ! -L $config ]] || { die 'daemon.json 为符号链接，请先明确其配置位置'; return 1; }
    init_run
    apply_daemon_config "$config" "${mirrors[@]}"
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
