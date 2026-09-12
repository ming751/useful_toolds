#!/usr/bin/env bash
module_chrome() {
    install_app google-chrome-stable google-chrome https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
}
module_chatgpt() {
    install_app chatgpt chatgpt https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb
}
module_wechat() {
    install_app wechat wechat https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb
}
module_code() {
    install_app code code https://update.code.visualstudio.com/latest/linux-deb-x64/stable
    local code_path extensions extension
    code_path=$(user_command code)
    extensions=$(as_user "$code_path" --list-extensions)
    for extension in ms-python.python ms-python.vscode-pylance ms-vscode.cpptools ms-vscode.cmake-tools; do
        if grep -Fxiq "$extension" <<< "$extensions"; then event 已有跳过 "VS Code: $extension"
        else
            as_user "$code_path" --install-extension "$extension"
            event 安装完成 "VS Code: $extension"
        fi
    done
}
