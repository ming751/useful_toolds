# 安装行为与默认设置

## 适用范围

已安装并正常启动的 Ubuntu 24.04 x86_64 GNOME 桌面。WSL、试用 U 盘、其他 Ubuntu 版本和其他桌面环境不在本版支持范围内。

从普通用户账号运行 `bash setup.sh`。脚本确认系统后使用 sudo 执行系统安装，用户配置和 Python 环境通过原普通用户写入。直接登录 root 不支持。`--dry-run` 和 `--help` 无需 sudo。

下载前需自行准备网络。脚本不安装代理客户端，不读取代理订阅，不更换 Ubuntu/Python 镜像。已经设置的 `http_proxy`、`https_proxy`、`all_proxy`、`no_proxy`（及其大写形式）会传给安装进程，不写入全局配置或日志。Docker 服务有独立的联网设置，详见 Docker 说明。

## 中文菜单与命令行

无参数显示推荐全选的中文菜单。`[✓]` 表示勾选安装，`[ ]` 表示不安装。输入编号选择或取消；多个编号用空格或逗号分隔。`a` 全选、`n` 全不选、`p` 查看计划、`q` 退出，回车开始执行。

`--only` 和 `--skip` 用逗号分隔模块名，并直接执行选择结果。`--only` 指定起始集合，随后排除 `--skip`，再补齐依赖；执行顺序固定，不受参数中排列顺序影响。重复模块只执行一次。未知模块、空列表、缺少参数或显式排除必要依赖，会在安装前报错。

目前 `terminal` 依赖 `shell`。例如 `--only terminal` 同时配置 Zsh，`--only terminal --skip shell` 会报错。其余模块自行准备最小的软件包依赖；例如 `--only robotics` 为 pyserial 创建 Python 环境，但不安装整套科学计算库。

`--yes` 跳过菜单，`--dry-run` 仅打印选择结果；预览不进行联网或提权，也不会运行安装动作。`--git-name` 和 `--git-email` 需要同时选中 `tools`，未提供的字段保持原值。

## 已有就跳过的含义

| 对象 | 检查与补齐方式 |
| --- | --- |
| APT 软件包 | `dpkg-query` 确认为安装完成后跳过；仅请求缺失软件包 |
| 独立应用 | APT 包或用户可执行文件已存在时保留，不下载第二份 |
| VS Code | 逐个检查扩展，只安装缺少的扩展 |
| Python | 检查 `dev` 虚拟环境、Python 版本、pip 和各库；只安装缺少的库 |
| Zsh | 软件存在仍检查用户默认 Shell，配置引用只补一次 |
| 用户模板 | 文件存在时保留个人内容，只创建缺少的文件 |
| Docker | 分别检查 Engine、Compose、Buildx；保留现有软件来源 |
| NVIDIA | 驱动正常时跳过；驱动包已有但不可用时提示后续操作 |

脚本不会主动更新已有软件。安装新包所需的依赖仍由 APT/pip 正常解析，可能补装或调整依赖；APT 禁止自动删除现有软件包。Ubuntu Universe 组件缺失且所选软件需要它时会启用该组件。

已有但损坏的 Python 环境、不可执行的 Starship 文件、与 Docker CE 冲突的安装，会明确报错，不删除后重建。出现库导入错误时会报告模块失败，不能将“文件存在”当成环境正常。

## 终端与 Zsh

安装 GNOME Terminal，用户默认 Shell 设为 `/usr/bin/zsh`（实际使用系统找到的 Zsh 路径）。项目创建的终端配置档使用该默认 Shell，不嵌套启动 Bash/Zsh。

新机创建独立的 **Useful Toolds — Midnight** 配置档，首次设为默认，使用 Midnight 配色及 Ubuntu Sans Mono 13 字体。已有其他终端配置档保留；重跑不会重置该配置档或用户后来选择的默认配置档。

Starship 从官方发布渠道安装到 `~/.local/bin/starship`。默认单行提示符，不在开头换行，目录显示最后两级，带 Git 状态与耗时。已有 Starship 或个人主题保留，不额外安装 Oh My Zsh。

配置文件：

- `~/.config/useful-toolds/shell.zsh`：历史、补全、fzf、别名等默认设置。
- `~/.config/useful-toolds/plugins.zsh`：命令建议与语法高亮。
- `~/.config/useful-toolds/prompt.zsh`：新机的 Starship 初始化。
- `~/.config/starship.toml`：提示符外观。

`.zshrc` 开头补充基础配置引用，后面保留原有配置；原有别名等设置可覆盖项目默认值。检测到已有主题或外部 Shell 配置引用时，保留原主题，不追加另一套 Starship 提示符初始化。

重新登录后打开终端，执行 `ps -p $$ -o comm=` 查看实际 Shell。`echo "$SHELL"` 只表示登录 Shell 环境变量，不代表当前进程。当前打开的旧窗口不会自动切换。

## 中文输入

Fcitx 5 拼音与 GTK 3/4、Qt 5/6 前端，默认 Shift 或 Ctrl＋空格切换，七个候选项，中文字体与随系统深色模式变化的候选框。通过 `im-config` 配置登录启动，并补齐 GNOME 的 GTK 输入模块设置。

`~/.config/fcitx5/` 内已有配置与词库保留。若 `.xinputrc` 明确选择了其他输入法，则保留这个选择，结果中提示如何手动改为 Fcitx 5；新机没有明确选择时配置 Fcitx 5。需要重新登录后再检查实际中文输入。

## 开发与机器人基础

C++ 工具链包含 GCC/G++、CMake、Ninja、GDB、clangd、clang-format、ccache、pkg-config、OpenSSL 开发头文件；VS Code 包含 Python、Pylance、C++ 和 CMake Tools 扩展。

Python `dev` 环境位于 `~/.venvs/dev`，使用 Ubuntu 的 Python 3.12，不设置系统 Python 别名，不向系统解释器执行 pip 安装。已有不同版本的 `dev` 环境会提示检查，不自动替换。

机器人基础模块提供 Eigen 矩阵库、yaml-cpp 配置解析、minicom 串口调试、pyserial、USB/PCI 查看、SSH 客户端、rsync 和 tmux。当前用户加入 `dialout` 组，重新登录后通常可以访问串口；不会对所有设备设置宽泛写权限，也不会安装或开启 SSH 服务。

NVIDIA 只处理基础显卡驱动。没有 NVIDIA 显卡则跳过；正常驱动保留；缺失时使用 Ubuntu 推荐驱动。驱动包已存在但 `nvidia-smi` 不可用时，提示重启、可能的 MOK 注册及进一步排错，不重复安装或关闭 Secure Boot。

## 应用安装与更新

首次安装使用官方渠道：

- [Chrome](https://www.google.com/chrome/)：官方当前 amd64 DEB。
- [VS Code](https://code.visualstudio.com/docs/setup/linux)：官方 Stable DEB。
- [ChatGPT](https://learn.chatgpt.com/docs/linux/linux-app)：官方 Linux DEB。
- [微信 Linux 版](https://linux.weixin.qq.com/)：官方 x86_64 DEB。

下载先写入临时文件，成功后才替换缓存；包名和架构匹配后才安装。已有应用直接跳过，不管理账号登录和聊天数据，不加入旧版 ChatGPT 修复逻辑。

ChatGPT 首装会配置官方签名 APT 源，后续需要更新时可以自行执行：

```bash
sudo apt update
sudo apt install --only-upgrade chatgpt
```

## 失败、备份与重试

各模块独立执行；必要依赖失败时，其后续模块标为未执行。例如 Shell 失败会阻止终端配置，但不阻止独立应用安装。一次软件源刷新失败后，本轮需要 APT 的后续操作会报告同一阻塞，避免连续重复联网；排错后重新运行即可。

最后按“已有跳过、安装完成、配置补齐、未执行、失败、待登录、待重启、待操作”汇总。有失败或依赖阻塞时退出码为非零。安装完成但等待重启/登录的项目会单独显示，不能视为功能已经可用。

- 日志：`/var/log/useful-toolds-日期-进程号.log`。
- 系统及通过 root 修改的配置备份：`/var/backups/useful-toolds/日期-进程号/`。
- 用户配置备份：`~/.local/state/useful-toolds/backups/日期-进程号/`，仅修改已有配置时产生。
- 下载缓存：`/var/cache/useful-toolds/`。

这些备份用于恢复配置，不是整机回滚或软件卸载方案。用户文件备份按 home 中的原路径保存；终端和 GNOME 设置的备份为 JSON，记录修改前的值。

重试命令会保留失败模块及需要的 Git 参数。也可以重新运行菜单，脚本会跳过已经满足要求的项目。

## 验证范围

仓库提供 Bash/Zsh 语法检查与隔离测试，覆盖菜单、参数、补装、配置保留、下载失败、模块失败隔离和 Docker 配置恢复。测试使用临时目录、模拟系统命令；GNOME 设置测试使用内存后端，不修改当前桌面。

尚未在一台全新 Ubuntu 上执行全套安装。应用 GUI 启动、输入法输入、登录后默认 Zsh 和重启后显卡可用性，应在目标新机实际确认。脚本不默认拉取测试容器或执行整套端到端测试。
