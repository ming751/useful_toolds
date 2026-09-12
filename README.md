# useful_toolds

把新装的 **Ubuntu 24.04 LTS x86_64 桌面版**配置成日常与机器人开发工作站。

**先检查，已有的跳过；缺少的软件和配置才补齐。** 不需要一次记住一长串安装命令。

## 新电脑怎么用

先自行准备好网络或代理，再下载本仓库。Ubuntu 已有 Git 时：

```bash
git clone https://github.com/ming751/useful_toolds.git
cd useful_toolds
bash setup.sh
```

没有 Git 时可以先执行 `sudo apt install git`，或在 GitHub 下载仓库 ZIP 并解压。在仓库目录运行 `bash setup.sh` 即可；请从普通用户账号启动，安装时会请求 sudo 密码。

菜单中：

- `[✓]`：勾选安装；`[ ]`：不安装。
- 直接按回车：安装预选的推荐项目。
- 输入编号：选中或取消该项；支持多个编号，例如 `4 7 8`。
- `a`：全选；`n`：取消全选；`p`：查看当前计划；`q`：退出。
- 选择终端会自动选择 Zsh；取消 Zsh 会同时取消依赖它的终端配置。

## 推荐安装内容

| 类别 | 内容 |
| --- | --- |
| 系统基础 | 证书、下载、解压、系统与网络查看工具；按硬件检测 NVIDIA 驱动 |
| 终端桌面 | GNOME Terminal、默认 Zsh、Starship、Midnight 配色、补全与高亮、中文字体、Fcitx 5 拼音 |
| 日常应用 | Chrome、VS Code、官方 ChatGPT、微信 Linux 版 |
| 通用开发 | Git、GCC/G++、CMake、Ninja、GDB、clangd、Python 独立环境、Docker/Compose/Buildx |
| 机器人基础 | Eigen、yaml-cpp、串口调试、pyserial、USB/PCI 查看、SSH 客户端、rsync、tmux |

Python 使用系统 Python 3.12，在 `~/.venvs/dev` 创建环境，包含 NumPy、SciPy、Pandas、Matplotlib、JupyterLab、pyserial。不会向系统 Python 安装 pip 库，也不会在开终端时自动激活环境。

第一版不安装代理软件、Conda、CUDA Toolkit、GPU 容器、PyTorch、ROS 2、OpenCV、PCL 或 CAN 工具。系统语言、时区和现有网络设置保留；不进行全系统升级、磁盘调整或自动重启。

## 常用命令

```bash
# 只看默认计划，不联网、不提权、不写文件
bash setup.sh --dry-run

# 不进入菜单，直接安装推荐配置
bash setup.sh --yes

# 只安装终端和 Python；终端自动补选 Zsh
bash setup.sh --only terminal,python

# 默认配置中跳过 NVIDIA 驱动与微信
bash setup.sh --skip nvidia,wechat

# 明确提供时才写入 Git 身份
bash setup.sh --only tools --git-name '你的名字' --git-email 'you@example.com'
```

可选模块：`base`、`shell`、`terminal`、`chinese`、`chrome`、`code`、`chatgpt`、`wechat`、`tools`、`python`、`docker`、`nvidia`、`robotics`。名称对应菜单中的功能。

## 完成后

按结果提示重新登录，驱动提示需要重启时再重启。新终端默认进入 Zsh；Fcitx 5 默认用 Shift 或 Ctrl＋空格切换拼音。应用从系统应用菜单打开，账号由自己登录。

需要 Python 环境时：

```bash
source ~/.venvs/dev/bin/activate
python -c "import numpy, scipy, pandas, matplotlib, serial"
# 结束使用
deactivate
```

重跑脚本会保留已有软件、配置和环境，补齐缺失项；不会自动把已有应用升级到最新版。失败项目会显示原因、日志位置和可复制的重试命令。

## 详细说明

- [安装行为、默认配置与排错](docs/setup.md)
- [Docker 安装说明](docs/install_docker.md)
- [Docker 命令与配置速查](docs/cheatsheets/docker.md)

已有入口仍可使用：`bash scripts/setup_linux.sh`、`bash scripts/shell/setup_zsh.sh`、`bash scripts/docker/install_docker.sh`。

## 仓库维护

- `setup.sh`：简短启动入口。
- `scripts/setup_linux.sh`、`scripts/lib/`：选择、依赖顺序、逐项检测与结果汇总。
- `scripts/modules/`：独立功能模块；`scripts/helpers/`：配置文件处理。
- `templates/`：新机默认配置；`docs/`：使用说明。
- `tests/`：临时目录和模拟系统命令的隔离测试，不执行真实安装。

运行相关测试：`python3 -m unittest discover -s tests -v`。完整新机安装、GUI 应用启动、输入法及重启后的显卡状态仍需要在实际新机验证。
