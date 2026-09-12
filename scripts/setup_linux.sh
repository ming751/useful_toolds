#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(dirname -- "$SCRIPT_DIR")
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/runner.sh
source "$SCRIPT_DIR/lib/runner.sh"
for module_file in "$SCRIPT_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$module_file"
done

main() {
    parse_args "$@"
    if ((SHOW_MENU && !DRY_RUN)); then selection_menu; fi
    resolve_modules
    print_plan
    if ((DRY_RUN)); then
        printf '\n预览结束：没有联网、提权、安装或修改文件。\n'
        return 0
    fi
    check_platform
    if ((EUID != 0)); then
        local -a args=(--only "$(join_modules "${MODULES[@]}")")
        [[ -z $GIT_NAME ]] || args+=(--git-name "$GIT_NAME")
        [[ -z $GIT_EMAIL ]] || args+=(--git-email "$GIT_EMAIL")
        exec sudo --preserve-env=http_proxy,https_proxy,all_proxy,no_proxy,HTTP_PROXY,HTTPS_PROXY,ALL_PROXY,NO_PROXY \
            bash "$SCRIPT_DIR/setup_linux.sh" "${args[@]}"
    fi
    resolve_user
    init_run
    run_modules
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
