#!/usr/bin/env bash
ensure_docker_repository() {
    if grep -RqsE '^[^#]*https://download\.docker\.com/linux/ubuntu' /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
        return 0
    fi
    apt_install ca-certificates curl
    local source_file=/etc/apt/sources.list.d/useful-toolds-docker.sources
    [[ ! -e $source_file && ! -L $source_file ]] || { die "$source_file 已存在但未包含预期软件源，请检查"; return 1; }
    install -d -m 0755 /etc/apt/keyrings
    fetch https://download.docker.com/linux/ubuntu/gpg "$CACHE_DIR/docker.asc"
    backup_file /etc/apt/keyrings/useful-toolds-docker.asc
    install -m 0644 "$CACHE_DIR/docker.asc" /etc/apt/keyrings/useful-toolds-docker.asc
    cat > "$source_file" <<'REPO'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/useful-toolds-docker.asc
REPO
    event 配置补齐 'Docker 官方 APT 软件源'
    rm -f -- "$RUN_DIR/apt-refreshed"
}
module_docker() {
    local flavor=docker-ce package docker_path
    if installed docker.io; then flavor=docker.io
    elif ! installed docker-ce; then
        if docker_path=$(user_command docker); then
            event 已有跳过 '保留非 APT 安装的 Docker'
            as_user "$docker_path" compose version
            as_user "$docker_path" buildx version
            as_user "$docker_path" info >/dev/null
            return 0
        fi
        for package in podman-docker docker-desktop containerd runc docker-compose docker-compose-v2 docker-buildx; do
            if installed "$package"; then die "检测到 $package，与新装 Docker CE 可能冲突；请先决定是否迁移，或跳过 docker"; return 1; fi
        done
    fi
    local -a packages=()
    if [[ $flavor == docker.io ]]; then
        packages=(docker.io)
        if ! as_user docker compose version >/dev/null 2>&1; then packages+=(docker-compose-v2); fi
        if ! as_user docker buildx version >/dev/null 2>&1; then packages+=(docker-buildx); fi
        universe_install "${packages[@]}"
    else
        packages=(docker-ce docker-ce-cli containerd.io)
        if ! as_user docker compose version >/dev/null 2>&1; then packages+=(docker-compose-plugin); fi
        if ! as_user docker buildx version >/dev/null 2>&1; then packages+=(docker-buildx-plugin); fi
        for package in "${packages[@]}"; do
            if ! installed "$package"; then ensure_docker_repository; break; fi
        done
        apt_install "${packages[@]}"
    fi
    ensure_group docker
    if ! systemctl is-enabled --quiet docker; then systemctl enable docker; event 配置补齐 'Docker 开机启动'; fi
    if ! systemctl is-active --quiet docker; then systemctl start docker; event 配置补齐 'Docker 服务启动'; fi
    docker --host unix:///var/run/docker.sock info >/dev/null
    as_user docker compose version
    as_user docker buildx version
}
