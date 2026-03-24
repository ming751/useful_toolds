# useful_toolds

查看本机ip
```bash
hostname -I
```
查看用户名
```bash
whoami
```
1. 构建并启动容器 (后台运行)
这个命令会自动读取 docker-compose.yml，寻找 Dockerfile 进行构建，并使用文件里的配置拉起容器：
```bash
docker compose up -d --build
```
2. 进入容器内部
容器启动后，你可以通过以下命令进入容器的终端进行开发编译操作（注意这里使用的是文件中定义的 service 名称 ros1-franka）：
```bash
docker compose exec ros1-franka /bin/bash
```
