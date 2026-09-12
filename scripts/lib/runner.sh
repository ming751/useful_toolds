#!/usr/bin/env bash
ALL_MODULES=(base shell terminal chinese chrome code chatgpt wechat tools python docker nvidia robotics)
MODULES=("${ALL_MODULES[@]}")
SKIP_MODULES=()
DRY_RUN=0
SHOW_MENU=1
GIT_NAME=''
GIT_EMAIL=''
label() {
    case $1 in
        base) echo '系统基础：证书、下载、解压与系统工具' ;;
        shell) echo '终端桌面：Zsh、Starship、补全与历史搜索' ;;
        terminal) echo '终端桌面：GNOME Terminal、Midnight 配色（依赖 shell）' ;;
        chinese) echo '终端桌面：中文字体、Fcitx 5 拼音' ;;
        chrome) echo '日常应用：Chrome' ;; code) echo '日常应用：VS Code 与 C++/Python 扩展' ;;
        chatgpt) echo '日常应用：官方 ChatGPT' ;; wechat) echo '日常应用：微信 Linux 版' ;;
        tools) echo '通用开发：Git、C++ 工具链' ;; python) echo '通用开发：Python dev 独立环境' ;;
        docker) echo '通用开发：Docker、Compose、Buildx' ;;
        nvidia) echo '系统基础：按硬件检测 NVIDIA 驱动' ;;
        robotics) echo '机器人基础：Eigen、YAML、串口、SSH、rsync、tmux' ;;
    esac
}
usage() {
    cat <<'HELP'
Ubuntu 24.04 x86_64 新电脑配置（网络需提前准备）
  bash scripts/setup_linux.sh                     分层菜单，默认全选
  bash scripts/setup_linux.sh --yes               安装默认项目
  bash scripts/setup_linux.sh --only terminal,python
  bash scripts/setup_linux.sh --skip nvidia,wechat
  bash scripts/setup_linux.sh --dry-run            只读预览，不联网、不提权
  bash scripts/setup_linux.sh --only tools --git-name '姓名' --git-email '邮箱'

模块：base shell terminal chinese chrome code chatgpt wechat tools python docker nvidia robotics
terminal 自动补选 shell；显式跳过必要依赖会报错。参数指定模块后不进入菜单。
已安装的软件跳过；只补缺失配置与依赖，不自动更新全套软件或重启。
HELP
}
contains() { local sought=$1; shift; local value; for value in "$@"; do [[ $value != "$sought" ]] || return 0; done; return 1; }
join_modules() { local IFS=,; printf '%s' "$*"; }
parse_list() {
    local value=$1 item
    [[ -n $value && $value != ,* && $value != *, && $value != *,,* ]] || { die '模块列表不能为空或包含空项'; return 1; }
    local -a items=()
    IFS=, read -r -a items <<< "$value"
    for item in "${items[@]}"; do
        contains "$item" "${ALL_MODULES[@]}" || { die "未知模块：$item"; return 1; }
    done
}
parse_args() {
    local arg
    while (($#)); do
        arg=$1; shift
        case $arg in
            --help|-h) usage; exit 0 ;;
            --yes|-y) SHOW_MENU=0 ;;
            --dry-run) DRY_RUN=1 ;;
            --only|--skip|--git-name|--git-email)
                (($#)) && [[ -n $1 && $1 != --* && $1 != *$'\n'* ]] || { die "$arg 缺少有效参数"; return 1; }
                case $arg in
                    --only) parse_list "$1"; IFS=, read -r -a MODULES <<< "$1"; SHOW_MENU=0 ;;
                    --skip) parse_list "$1"; IFS=, read -r -a SKIP_MODULES <<< "$1"; SHOW_MENU=0 ;;
                    --git-name) GIT_NAME=$1 ;;
                    --git-email) GIT_EMAIL=$1 ;;
                esac
                shift ;;
            *) die "未知参数：$arg"; return 1 ;;
        esac
    done
}
selection_menu() {
    [[ -t 0 ]] || { die '非交互输入请使用 --yes 或 --only；查看计划使用 --dry-run'; return 1; }
    local answer index module
    local -a selected=("${MODULES[@]}") next=()
    while true; do
        printf '\n========== Ubuntu 新电脑配置 ==========\n'
        printf '默认已选好推荐配置。已有软件会自动跳过，只补缺失项。\n'
        printf '[✓] 勾选表示安装；[ ] 未勾选表示不安装。\n'
        printf '输入编号切换选择；a 全选；n 全不选；p 查看计划；q 退出。\n'
        printf '直接按回车开始。也可以一次输入多个编号，例如：4 7 8。\n\n'
        index=0
        for module in "${ALL_MODULES[@]}"; do
            index=$((index + 1))
            if contains "$module" "${selected[@]}"; then answer='✓'; else answer=' '; fi
            printf '%2d [%s] %s\n' "$index" "$answer" "$(label "$module")"
        done
        read -r -p '> ' answer || return 1
        case $answer in
            '')
                if ((${#selected[@]} == 0)); then printf '请至少选择一项。\n'; continue; fi
                MODULES=("${selected[@]}"); return 0 ;;
            q|Q) exit 0 ;;
            a|A) selected=("${ALL_MODULES[@]}"); continue ;;
            n|N) selected=(); continue ;;
            p|P) MODULES=("${selected[@]}"); print_plan; continue ;;
        esac
        local -a choices=() toggled=()
        local choice valid=1 item deselected_shell=0
        read -r -a choices <<< "${answer//,/ }"
        for choice in "${choices[@]}"; do
            if [[ ! $choice =~ ^[0-9]{1,2}$ ]] || ((10#$choice < 1 || 10#$choice > ${#ALL_MODULES[@]})); then valid=0; fi
        done
        if (( !valid || ${#choices[@]} == 0 )); then printf '请输入有效编号。\n'; continue; fi
        for choice in "${choices[@]}"; do
            module=${ALL_MODULES[10#$choice-1]}
            contains "$module" "${toggled[@]}" && continue
            toggled+=("$module")
            if contains "$module" "${selected[@]}"; then
                next=()
                for item in "${selected[@]}"; do
                    [[ $item == "$module" ]] || next+=("$item")
                done
                selected=("${next[@]}")
                if [[ $module == shell ]]; then deselected_shell=1; fi
            else
                selected+=("$module")
            fi
        done
        # Apply dependency changes after the whole batch; "2 3" must not reselect both.
        if ((deselected_shell)); then
            next=()
            for item in "${selected[@]}"; do [[ $item == terminal ]] || next+=("$item"); done
            selected=("${next[@]}")
        elif contains terminal "${selected[@]}" && ! contains shell "${selected[@]}"; then
            selected+=(shell)
        fi
    done
}
dependencies() { if [[ $1 == terminal ]]; then echo shell; fi; }
resolve_modules() {
    local module dep
    local -a chosen=() ordered=()
    for module in "${MODULES[@]}"; do contains "$module" "${SKIP_MODULES[@]}" || chosen+=("$module"); done
    if [[ -n $GIT_NAME || -n $GIT_EMAIL ]]; then
        contains tools "${chosen[@]}" || { die 'Git 身份参数需要选择 tools 模块'; return 1; }
    fi
    for module in "${chosen[@]}"; do
        for dep in $(dependencies "$module"); do
            contains "$dep" "${SKIP_MODULES[@]}" && { die "$module 依赖 $dep，不能同时跳过 $dep"; return 1; }
            contains "$dep" "${chosen[@]}" || chosen+=("$dep")
        done
    done
    for module in "${ALL_MODULES[@]}"; do contains "$module" "${chosen[@]}" && ordered+=("$module"); done
    MODULES=("${ordered[@]}")
    ((${#MODULES[@]})) || { die '没有选中任何模块'; return 1; }
}
print_plan() {
    printf '\n安装范围：Ubuntu 24.04 x86_64，已有满足要求的项目跳过。\n'
    local module
    for module in "${MODULES[@]}"; do printf '  %-10s %s\n' "$module" "$(label "$module")"; done
}
run_modules() {
    local module dep blocked status
    local -A outcomes=()
    local -a failed=() completed=()
    for module in "${MODULES[@]}"; do
        blocked=''
        for dep in $(dependencies "$module"); do [[ ${outcomes[$dep]:-} == ok ]] || blocked=$dep; done
        CURRENT_MODULE=$module
        if [[ -n $blocked ]]; then
            event 未执行 "$module 的依赖 $blocked 未完成"
            failed+=("$module"); outcomes[$module]=blocked; continue
        fi
        info "检查并配置：$(label "$module")"
        # An if/|| around this subshell would disable errexit inside all helpers.
        set +e
        (
            set -Eeuo pipefail
            trap 'printf "[模块失败] %s，第 %s 行，退出码 %s\n" "$CURRENT_MODULE" "$LINENO" "$?" >&2' ERR
            "module_$module"
        )
        status=$?
        set -e
        if ((status == 0)); then outcomes[$module]=ok; completed+=("$module")
        else outcomes[$module]=failed; failed+=("$module"); event 失败 "$module（退出码 $status）"; fi
    done
    info "已处理模块：${completed[*]:-无}"
    local kind
    for kind in 已有跳过 安装完成 配置补齐 未执行 失败 待登录 待重启 待操作; do
        if awk -F '\t' -v kind="$kind" '$2==kind {found=1} END {exit !found}' "$EVENT_FILE"; then
            printf '\n%s：\n' "$kind"
            awk -F '\t' -v kind="$kind" '$2==kind {printf "  [%s] %s\n", $1, $3}' "$EVENT_FILE"
        fi
    done
    info "系统配置备份：$BACKUP_DIR；日志：$LOG_FILE"
    info "用户配置备份：$USER_HOME/.local/state/useful-toolds/backups/$RUN_ID（仅修改时创建）"
    if ((${#failed[@]})); then
        printf '\n排查日志后重试：bash %q --only %s' "$SCRIPT_DIR/setup_linux.sh" "$(join_modules "${failed[@]}")"
        if contains tools "${failed[@]}"; then
            [[ -z $GIT_NAME ]] || printf ' --git-name %q' "$GIT_NAME"
            [[ -z $GIT_EMAIL ]] || printf ' --git-email %q' "$GIT_EMAIL"
        fi
        printf '\n'
        return 1
    fi
    return 0
}
