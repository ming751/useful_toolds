# Docker 安装与验证指南（Ubuntu）

本文记录如何在 Ubuntu 上从 0 开始安装 Docker Engine、Docker Compose v2，并完成基础验证。

如果你想直接一键安装，可以优先运行：

```bash
sudo ./scripts/docker/install_docker.sh
```

> 适用场景：
> - Ubuntu 本机
> - WSL Ubuntu
> - 远程 Ubuntu 服务器

---

## 1. 卸载旧版本（可选但推荐）

如果系统里装过旧版 Docker，先卸载，避免包冲突：

```bash
sudo apt-get remove docker docker-engine docker.io containerd runc
```

---

## 2. 安装基础依赖

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

---

## 3. 添加 Docker 官方 GPG 密钥

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

---

## 4. 添加 Docker 官方 APT 软件源

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

更新软件包索引：

```bash
sudo apt-get update
```

---

## 5. 安装 Docker Engine 与 Compose 插件

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

说明：

- `docker-ce`：Docker Engine
- `docker-ce-cli`：Docker 命令行
- `containerd.io`：容器运行时
- `docker-buildx-plugin`：Buildx 插件
- `docker-compose-plugin`：Docker Compose v2 插件

---

## 6. 启动 Docker 并设置开机自启

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

检查服务状态：

```bash
sudo systemctl status docker
```

如果看到 `active (running)`，说明 Docker 服务已正常启动。

---

## 7. 将当前用户加入 docker 组（避免每次都 sudo）

先创建 `docker` 组（如果已存在也没关系）：

```bash
sudo groupadd docker
```

将当前用户加入 `docker` 组：

```bash
sudo usermod -aG docker $USER
```

然后 **重新登录终端**，或者执行：

```bash
newgrp docker
```

> 注意：`docker` 组等价于较高主机权限，不要随便给不可信用户加入该组。

---

## 7.1 推荐：配置 Docker daemon 镜像加速

在国内网络环境下，建议安装完成后立刻配置镜像加速，否则 `docker pull` 往往会很慢，甚至失败。

如果你想看详细说明和完整复制版命令，请直接查看：

- [`docs/cheatsheets/docker.md`](cheatsheets/docker.md)

如果你想一键完成配置，可以直接运行：

```bash
sudo ./scripts/docker/configure_daemon.sh
```

核心配置文件位置：

```bash
/etc/docker/daemon.json
```

---

## 8. 验证安装是否成功

### 8.1 查看 Docker 版本

```bash
docker --version
```

### 8.2 查看 Compose 版本

```bash
docker compose version
```

> 现在推荐使用：
>
> ```bash
> docker compose
> ```
>
> 而不是旧版：
>
> ```bash
> docker-compose
> ```

### 8.3 运行官方测试容器

```bash
docker run hello-world
```

如果输出包含类似 `Hello from Docker!` 的信息，说明 Docker Engine 工作正常。

### 8.4 查看容器列表

```bash
docker ps
docker ps -a
```

---

## 9. 基础使用测试

### 9.1 拉取镜像

```bash
docker pull nginx
```

### 9.2 启动一个测试容器

```bash
docker run -d --name test-nginx -p 8080:80 nginx
```

查看运行状态：

```bash
docker ps
```

浏览器访问：

```text
http://localhost:8080
```

如果是在远程服务器上，请将 `localhost` 换成服务器 IP。

### 9.3 停止并删除测试容器

```bash
docker stop test-nginx
docker rm test-nginx
```

---

## 10. 验证 Docker Compose

先创建测试目录：

```bash
mkdir -p ~/docker-compose-test
cd ~/docker-compose-test
```

创建 `compose.yaml`：

```yaml
services:
  web:
    image: nginx:latest
    ports:
      - "8081:80"
```

启动：

```bash
docker compose up -d
```

查看服务：

```bash
docker compose ps
```

访问：

```text
http://localhost:8081
```

停止并清理：

```bash
docker compose down
```

---

## 11. 常见问题

### 11.1 `docker: permission denied while trying to connect to the Docker daemon socket`

通常是当前用户还没加入 `docker` 组，或者组权限还没生效。

处理方法：

```bash
sudo usermod -aG docker $USER
newgrp docker
```

重新验证：

```bash
docker ps
```

---

### 11.2 `E: Unable to locate package docker-compose-plugin`

原因通常是还没有添加 Docker 官方 APT 仓库，而是在 Ubuntu 默认源里直接安装。  
解决方法就是重新执行本文第 3～5 步。

---

### 11.3 `docker-compose` 命令不存在

这是正常情况。新版本 Compose 默认使用：

```bash
docker compose
```

不是：

```bash
docker-compose
```

如果某些旧脚本硬编码了 `docker-compose`，那是脚本太旧，不是当前安装有问题。

---

## 12. 常用命令备忘

### Docker

```bash
docker --version
docker ps
docker ps -a
docker images
docker pull nginx
docker run hello-world
docker logs <container_name_or_id>
docker stop <container_name_or_id>
docker rm <container_name_or_id>
docker rmi <image_name_or_id>
```

### Docker Compose

```bash
docker compose version
docker compose up -d
docker compose down
docker compose ps
docker compose logs
docker compose logs -f
docker compose build
```

---

## 13. 本文安装结果的最小验证标准

如果下面命令都成功，则说明安装完成：

```bash
docker --version
docker compose version
docker run hello-world
docker ps
```

---

## 14. 参考说明

本文步骤基于 Docker 官方文档整理，核心依据包括：

- Ubuntu 上安装 Docker Engine：使用 Docker 官方 APT 仓库安装 Docker Engine
- Linux 上安装 Docker Compose plugin：Compose v2 作为 Docker CLI 插件安装
- Docker Linux post-install：将用户加入 `docker` 组以便非 root 使用
