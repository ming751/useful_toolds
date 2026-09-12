# Docker 常用命令与配置速查

## 安装与使用

```bash
bash setup.sh --only docker
docker info
docker ps -a
docker images
docker compose version
docker buildx version
```

有 `compose.yaml` 的项目目录中：

```bash
docker compose up -d --build
docker compose logs -f
docker compose exec <service_name> /bin/bash
docker compose down
```

## 合并 daemon 配置

```bash
bash scripts/docker/configure_daemon.sh --dry-run
bash scripts/docker/configure_daemon.sh
```

只有自行确定可信镜像地址后才提供 `--mirror`。下面的地址是占位示例，使用前请替换：

```bash
bash scripts/docker/configure_daemon.sh --mirror https://your-registry.example --dry-run
bash scripts/docker/configure_daemon.sh --mirror https://your-registry.example
```

支持重复 `--mirror` 添加多个地址。已有配置（包括 NVIDIA runtime）保留，相同地址不重复加入。

日志驱动没有配置时使用 `json-file`，默认补充缺少的 `max-size: 100m`、`max-file: 3`；其他日志驱动及已有轮转值保留。修改前备份，验证通过后写入，重启失败恢复配置；相同内容不会重启服务。

查看效果或排查启动失败：

```bash
docker info
systemctl status docker
journalctl -u docker -n 80 --no-pager
```

详细行为见 [Docker 安装说明](../install_docker.md)。
