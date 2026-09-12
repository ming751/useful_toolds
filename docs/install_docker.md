# Docker 安装说明

适用 Ubuntu 24.04 x86_64 桌面版。使用统一安装器：

```bash
bash setup.sh --only docker
# 旧入口也可用
bash scripts/docker/install_docker.sh
```

## 安装与跳过

- 新装：使用 [Docker 官方 Ubuntu APT 源](https://docs.docker.com/engine/install/ubuntu/)，安装 Docker CE、CLI、containerd.io、Compose 和 Buildx。
- 已有 Docker CE：跳过已有包，补缺少的组件。
- 已有 Ubuntu 的 `docker.io`：继续使用 Ubuntu 软件包来源，缺少插件时安装 `docker-compose-v2`、`docker-buildx`。
- Compose/Buildx 已通过用户插件安装且可执行时保留。
- 检测到其他方式的 Docker 安装时保留，并检查其组件是否可用，不自动迁移来源。
- 新装 Docker CE 遇到冲突包时报告错误，不自动卸载已有容器组件。

安装器将目标用户加入 `docker` 组，按需启用和启动服务，检查本机 Docker Engine、Compose、Buildx。已运行的 Docker 不因重跑安装器而重启。

`docker` 组允许控制主机 Docker，权限很高；这里用于个人开发机。新添加的组权限在重新登录后生效。

## 配置 daemon

主安装器不自动改写 `daemon.json`。需要日志轮转等配置时单独执行：

```bash
# 先看合并后的配置
bash scripts/docker/configure_daemon.sh --dry-run
# 配置缺失的默认项
bash scripts/docker/configure_daemon.sh
```

脚本保留原有字段、NVIDIA runtime、镜像地址及自定义日志设置。缺少日志驱动时使用 `json-file`，该驱动缺少轮转设置时补充 `100m × 3`。没有 `exec-opts` 时补充 systemd cgroup driver；已有设置保留。

镜像地址仅在显式传入 `--mirror` 时添加，不内置第三方地址，不替换已有列表。详见 [配置速查](cheatsheets/docker.md)。

合并结果由 `dockerd --validate` 检查后才写入。内容不变时不重启；重启失败时恢复原配置并尝试重新启动，错误和备份位置会显示在日志中。

## 安装后查看

重新登录后：

```bash
docker info
docker compose version
docker buildx version
```

这里不要求自动下载测试镜像。使用 Docker 拉取镜像失败时，先检查 Docker 服务自身的网络或代理设置：Shell 的代理环境变量不会自动配置到 Docker daemon。

## 常见问题

- **访问 socket 权限不足**：退出并重新登录，再用 `id -nG` 检查 `docker` 组。
- **Compose 找不到**：使用 `docker compose`；保留安装来源，重跑 `--only docker` 补齐插件。
- **服务未启动**：查看 `systemctl status docker` 和 `journalctl -u docker`；脚本不会把启动失败报告为成功。
- **软件源刷新失败**：修复网络或损坏的软件源后重试；脚本不自动关闭签名检查。
- **非 APT Docker 缺少组件**：先按该安装方式补齐组件，或自行决定迁移；脚本不会同时装另一套 Engine。
