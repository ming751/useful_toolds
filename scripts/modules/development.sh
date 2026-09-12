#!/usr/bin/env bash
module_base() {
    apt_install ca-certificates curl wget unzip zip tar xz-utils tree htop iproute2 iputils-ping
}
module_tools() {
    universe_install git build-essential cmake ninja-build gdb clangd clang-format ccache pkg-config libssl-dev vim
    local key value
    for key in name email; do
        if [[ $key == name ]]; then value=$GIT_NAME; else value=$GIT_EMAIL; fi
        [[ -n $value ]] || continue
        if [[ $(as_user git config --global --get "user.$key" || true) == "$value" ]]; then
            event 已有跳过 "Git user.$key"
        else
            backup_file "$USER_HOME/.gitconfig"
            backup_file "$USER_HOME/.config/git/config"
            as_user git config --global "user.$key" "$value"
            event 配置补齐 "Git user.$key"
        fi
    done
}
ensure_dev_env() {
    universe_install python3 python3-venv python3-pip python3-dev
    DEV_ENV="$USER_HOME/.venvs/dev"
    if [[ -e $DEV_ENV || -L $DEV_ENV ]]; then
        [[ -f $DEV_ENV/pyvenv.cfg && -x $DEV_ENV/bin/python ]] || { die "$DEV_ENV 已存在但不是完整虚拟环境，请检查；不会删除重建"; return 1; }
        as_user "$DEV_ENV/bin/python" -c 'import sys; assert sys.prefix != sys.base_prefix and sys.version_info[:2] == (3,12), "dev 环境需要 Python 3.12"'
        as_user "$DEV_ENV/bin/python" -m pip --version >/dev/null
        event 已有跳过 'Python dev 环境'
    else
        as_user mkdir -p "$USER_HOME/.venvs"
        as_user /usr/bin/python3 -m venv "$DEV_ENV"
        event 安装完成 'Python dev 环境'
    fi
}
pip_missing() {
    local specification package module
    local -a missing=()
    for specification in "$@"; do
        package=${specification%%:*}; module=${specification#*:}
        if as_user "$DEV_ENV/bin/python" -c 'import importlib.metadata as m, importlib.util, sys; names={d.metadata["Name"].lower() for d in m.distributions()}; sys.exit(sys.argv[1].lower() not in names or importlib.util.find_spec(sys.argv[2]) is None)' "$package" "$module"; then
            event 已有跳过 "dev: $package"
        else missing+=("$package"); fi
    done
    if ((${#missing[@]})); then
        as_user "$DEV_ENV/bin/python" -m pip install "${missing[@]}"
        event 安装完成 "dev: ${missing[*]}"
    fi
    # Import from this environment, never from the system interpreter.
    for specification in "$@"; do
        as_user "$DEV_ENV/bin/python" -c 'import importlib,sys; importlib.import_module(sys.argv[1])' "${specification#*:}"
    done
}
module_python() {
    ensure_dev_env
    pip_missing numpy:numpy scipy:scipy pandas:pandas matplotlib:matplotlib jupyterlab:jupyterlab pyserial:serial
    info "Python 激活：source \"$DEV_ENV/bin/activate\"（不会自动激活）"
}
module_robotics() {
    universe_install libeigen3-dev libyaml-cpp-dev minicom usbutils pciutils openssh-client rsync tmux
    ensure_dev_env
    pip_missing pyserial:serial
    ensure_group dialout
}
