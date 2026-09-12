#!/usr/bin/env bash
ensure_default_zsh() {
    local target current
    target=$(command -v zsh)
    current=$(getent passwd "$TARGET_USER" | cut -d: -f7)
    if [[ $current == "$target" ]]; then event 已有跳过 '默认 Shell 已为 Zsh'
    else
        chsh -s "$target" "$TARGET_USER"
        event 配置补齐 '默认 Shell 设置为 Zsh'
        event 待登录 '重新登录后打开终端直接进入 Zsh'
    fi
}
module_shell() {
    universe_install zsh zsh-autosuggestions zsh-syntax-highlighting fzf ripgrep fd-find bat eza python3
    local starship_path archive
    if starship_path=$(user_command starship); then
        as_user "$starship_path" --version >/dev/null
        event 已有跳过 Starship
    else
        [[ ! -e $USER_HOME/.local/bin/starship && ! -L $USER_HOME/.local/bin/starship ]] || { die '已有 Starship 文件不可执行，请检查'; return 1; }
        apt_install ca-certificates curl tar
        archive="$CACHE_DIR/starship.tar.gz"
        fetch https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz "$archive"
        # Extract the single executable, not paths or scripts from the archive.
        tar -xOf "$archive" starship > "$CACHE_DIR/starship.bin"
        chmod 0644 "$CACHE_DIR/starship.bin"
        as_user mkdir -p "$USER_HOME/.local/bin"
        as_user install -m 0755 "$CACHE_DIR/starship.bin" "$USER_HOME/.local/bin/starship"
        as_user "$USER_HOME/.local/bin/starship" --version >/dev/null
        event 安装完成 Starship
    fi
    user_config configure_shell.py
    as_user zsh -n "$USER_HOME/.zshrc"
    ensure_default_zsh
}
module_terminal() {
    apt_install gnome-terminal fonts-ubuntu python3-gi dbus-x11 dconf-cli
    user_config configure_desktop.py terminal
}
module_chinese() {
    universe_install fcitx5 fcitx5-chinese-addons fcitx5-config-qt fcitx5-frontend-gtk3 \
        fcitx5-frontend-gtk4 fcitx5-frontend-qt5 fcitx5-frontend-qt6 fonts-noto-cjk \
        im-config python3 python3-gi dbus-x11
    local selection=''
    if [[ -f $USER_HOME/.xinputrc ]]; then
        selection=$(sed -nE 's/^[[:space:]]*run_im[[:space:]]+([^[:space:]#]+).*$/\1/p' "$USER_HOME/.xinputrc")
    fi
    case $selection in
        ''|default|auto|fcitx5) ;;
        *) event 已有跳过 "保留当前输入法选择 $selection 和词库"; event 待操作 '如需改用 Fcitx 5，请运行 im-config -n fcitx5 并重新登录'; return 0 ;;
    esac
    user_config configure_desktop.py chinese
    if [[ $selection != fcitx5 ]]; then
        backup_file "$USER_HOME/.xinputrc"
        as_user im-config -n fcitx5
        event 配置补齐 'Fcitx 5 登录启动'
        event 待登录 '重新登录后启用 Fcitx 5 拼音'
    else event 已有跳过 'Fcitx 5 登录启动'; fi
}
