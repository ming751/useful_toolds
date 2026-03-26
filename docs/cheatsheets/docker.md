# Docker 常用命令与配置速查

这份文档用于保存 Docker 相关的高频命令，以及适合直接复制粘贴的配置片段。

## Docker 一键安装

如果你希望直接使用仓库里的安装脚本：

```bash
sudo ./scripts/docker/install_docker.sh
```

## Docker daemon 镜像加速 / 提高稳定性

在国内网络环境下，这一项非常重要。否则 `docker pull` 可能很慢，甚至直接失败。

### 1. 创建或编辑 `daemon.json`

```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

写入推荐配置：

```json
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
```

配置说明：

| 配置项 | 作用 |
| --- | --- |
| `registry-mirrors` | Docker Hub 镜像加速 |
| `log-driver` | 日志驱动 |
| `max-size` | 单个日志文件大小 |
| `max-file` | 日志文件数量 |
| `exec-opts` | 使用 `systemd` cgroup driver，Kubernetes / ROS / 仿真环境更稳定 |

### 2. 重启 Docker

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 3. 验证配置是否生效

```bash
docker info
```

### 一次性写入版本

如果你希望直接复制一整段命令，可以使用下面这版：

```bash
sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
docker info
```

### 一键脚本版本

如果你希望直接执行仓库里的脚本：

```bash
sudo ./scripts/docker/configure_daemon.sh
```
