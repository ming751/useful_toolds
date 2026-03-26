# useful_toolds

一个用于整理常用 Linux / Docker / 机器人开发环境命令与一键配置脚本的仓库。

这个仓库的目标不是堆很多零散命令，而是把内容分成两类：

- `scripts/`：可执行的一键式脚本
- `docs/`：可阅读、可检索的说明文档

## 快速导航

- 一键配置 Linux 开发环境：[`scripts/setup_linux.sh`](scripts/setup_linux.sh)
- 一键配置 Zsh / Shell 环境：[`scripts/shell/setup_zsh.sh`](scripts/shell/setup_zsh.sh)
- 一键安装 Docker：[`scripts/docker/install_docker.sh`](scripts/docker/install_docker.sh)
- 一键配置 Docker daemon 镜像加速：[`scripts/docker/configure_daemon.sh`](scripts/docker/configure_daemon.sh)
- Docker 安装与验证说明：[`docs/install_docker.md`](docs/install_docker.md)
- Docker 常用命令与镜像加速速查：[`docs/cheatsheets/docker.md`](docs/cheatsheets/docker.md)

## 仓库结构

```text
useful_toolds/
├── README.md
├── docs/
│   ├── cheatsheets/
│   │   └── docker.md
│   └── install_docker.md
└── scripts/
    ├── docker/
    │   ├── install_docker.sh
    │   └── configure_daemon.sh
    ├── shell/
    │   └── setup_zsh.sh
    └── setup_linux.sh
```

建议后续也按这个规则继续扩展：

- 新脚本放进 `scripts/`
- 新文档放进 `docs/`
- 如果命令开始变多，可以再拆出 `docs/cheatsheets/`
- 如果脚本按平台区分，可以再拆出 `scripts/linux/`、`scripts/wsl/`、`scripts/docker/`

## 当前内容说明

### `scripts/setup_linux.sh`

用于在 Ubuntu / Linux 环境中执行一键式基础配置，当前包含：

- 基础开发工具安装
- Python 常用科学计算库安装
- 调用独立脚本配置 Zsh + Oh My Zsh
- 调用独立脚本安装 Docker 与 `docker compose` 插件
- CUDA 配置脚本下载与执行
- NVIDIA Container Toolkit 配置
- CUDA / Torch 简单验证

注意事项：

- 需要 `sudo` 运行
- 脚本会联网下载依赖与外部脚本
- 脚本里的 ROS 2 安装部分目前是注释状态，默认不会执行

运行方式：

```bash
sudo ./scripts/setup_linux.sh
```

### `scripts/shell/setup_zsh.sh`

用于一键安装并配置终端 Shell 环境，当前包含：

- 安装 `zsh`
- 安装 `oh-my-zsh`
- 安装常用插件
- 配置 `.zshrc`
- 将默认 shell 切换为 `zsh`
- 保留现有 `plugins=...` 配置并补齐常用插件

当前默认启用的插件：

- `git`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

运行方式：

```bash
sudo ./scripts/shell/setup_zsh.sh
```

注意：

- 请从普通用户账号执行 `sudo` 后运行，不要直接用 root 运行

### `scripts/docker/install_docker.sh`

用于一键安装 Docker 运行环境，当前包含：

- 安装 `docker.io`
- 安装 `docker-compose-plugin`
- 创建并配置 `docker` 用户组
- 将当前用户加入 `docker` 组
- 尝试启用并重启 Docker 服务
- 安装完成后提示继续配置镜像加速

运行方式：

```bash
sudo ./scripts/docker/install_docker.sh
```

注意：

- 请从普通用户账号执行 `sudo` 后运行，不要直接用 root 运行

### `scripts/docker/configure_daemon.sh`

用于一键写入 Docker daemon 推荐配置，当前包含：

- Docker Hub 镜像加速源
- 日志轮转配置
- `systemd` cgroup driver
- 自动重启 Docker 服务
- 自动备份旧的 `daemon.json`

运行方式：

```bash
sudo ./scripts/docker/configure_daemon.sh
```

### `docs/install_docker.md`

这是独立的 Docker 安装手册，适合下面几种场景：

- 不想直接跑一键脚本，想分步骤安装
- 只想安装 Docker，不需要整套开发环境
- 想排查 Docker 安装失败时的具体步骤

### `docs/cheatsheets/docker.md`

这是 Docker 相关的速查文档，适合保存：

- 可以直接复制粘贴的命令
- daemon 配置片段
- 常用排查命令
- 针对国内网络环境的推荐配置

## 常用命令备忘

### 系统信息

查看本机 IP：

```bash
hostname -I
```

查看当前用户名：

```bash
whoami
```

### Docker Compose

下面这组命令适用于“当前目录已经有 `docker-compose.yml` 或 `compose.yaml`”的项目。
这个仓库本身目前没有提供 compose 文件，所以这里把它作为通用备忘，而不是仓库内置能力。

构建并后台启动容器：

```bash
docker compose up -d --build
```

进入容器：

```bash
docker compose exec <service_name> /bin/bash
```

例如：

```bash
docker compose exec ros1-franka /bin/bash
```

### Docker daemon 镜像加速

推荐优先使用脚本：

```bash
sudo ./scripts/docker/configure_daemon.sh
```

如果你只想复制配置命令，完整版本见：

- [`docs/cheatsheets/docker.md`](docs/cheatsheets/docker.md)

## 推荐使用方式

如果你想把这个仓库长期当作自己的“工具箱”，建议按下面方式维护：

1. 把“能自动化的步骤”优先沉淀成 `scripts/`
2. 把“需要解释背景和排错方法的内容”写进 `docs/`
3. README 只保留导航、入口和最常用命令，不堆太长的细节
4. 每增加一个脚本，就在 README 的“快速导航”里补一条入口

## 后续可以继续补充的方向

- `docs/cheatsheets/linux.md`：Linux 常用命令速查
- `scripts/install_ros2.sh`：把 ROS 2 安装逻辑独立出来
- `scripts/post_install_check.sh`：统一做环境验证
