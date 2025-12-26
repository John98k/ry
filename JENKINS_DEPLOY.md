# Jenkins 部署配置说明

## 前置要求

### 1. 服务器环境要求
- **操作系统**: Linux (推荐 Ubuntu 20.04+ / CentOS 7+)
- **Java**: JDK 8+
- **Node.js**: 18.x
- **Maven**: 3.9.x
- **Docker**: 20.10+
- **Docker Compose**: 2.x (可选)
- **Jenkins**: 2.400+

### 2. 依赖服务
- **MySQL**: 8.0+
- **Redis**: 7.0+

## Jenkins 配置步骤

### 步骤 1: 安装 Jenkins

#### Ubuntu/Debian
```bash
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install jenkins
sudo systemctl start jenkins
```

#### CentOS/RHEL
```bash
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install jenkins
sudo systemctl start jenkins
```

### 步骤 2: 配置 Jenkins 全局工具

1. 登录 Jenkins (默认端口 8080)
2. 进入 `Manage Jenkins` -> `Global Tool Configuration`

#### 2.1 配置 Maven
- **Name**: `Maven 3.9`
- **MAVEN_HOME**: `/usr/share/maven` (或你的 Maven 安装路径)

#### 2.2 配置 Node.js
- **Name**: `Node.js 18`
- **NodeJS Installers**: 选择 `Install from nodejs.org`
  - Version: `18.20.0`

#### 2.3 配置 JDK
- **Name**: `JDK 8`
- **JAVA_HOME**: `/usr/lib/jvm/java-8-openjdk-amd64` (或你的 JDK 安装路径)

### 步骤 3: 配置 Jenkins 用户权限

确保 Jenkins 用户有 Docker 权限：

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### 步骤 4: 创建 Jenkins 任务

1. 点击 `New Item`
2. 输入任务名称：`ruoyi-deploy`
3. 选择 `Pipeline`
4. 点击 `OK`

#### 4.1 配置 Pipeline
- **Definition**: `Pipeline script from SCM`
- **SCM**: `Git`
- **Repository URL**: `https://github.com/John98k/ry.git`
- **Credentials**: 添加 GitHub 凭据
  - 类型: `Username with password`
  - Username: `your-email@example.com`
  - Password: `your-personal-access-token`
- **Branch**: `*/master`
- **Script Path**: `Jenkinsfile`

### 步骤 5: 配置构建触发器（可选）

#### 5.1 定时构建
- Build periodically: `H H * * *` (每天构建一次)

#### 5.2 Webhook 触发
- GitHub hook trigger for GITScm polling: 勾选
- 在 GitHub 仓库设置中添加 Webhook:
  - Payload URL: `http://<你的Jenkins地址>/github-webhook/`
  - Content type: `application/json`

### 步骤 6: 配置环境变量（可选）

在 Pipeline 中可以自定义以下环境变量：

```groovy
environment {
    // 后端配置
    BACKEND_IMAGE = "ruoyi-backend"
    BACKEND_CONTAINER = "ruoyi-backend"
    BACKEND_PORT = "8080"
    
    // 前端配置
    FRONTEND_IMAGE = "ruoyi-frontend"
    FRONTEND_CONTAINER = "ruoyi-frontend"
    FRONTEND_PORT = "80"
    
    // 网络配置
    NETWORK_NAME = "ruoyi-net"
    
    // 日志挂载
    LOG_MOUNT = "${WORKSPACE}/logs:/home/ruoyi/logs"
}
```

## 部署流程

### 1. 启动依赖服务

#### MySQL
```bash
docker run -d \
  --name mysql \
  --network ruoyi-net \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=root123456 \
  -e MYSQL_DATABASE=ry-vue \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

#### Redis
```bash
docker run -d \
  --name redis \
  --network ruoyi-net \
  -p 6379:6379 \
  redis:7.0
```

### 2. 导入数据库

```bash
# 将数据库 SQL 文件复制到 MySQL 容器
docker cp mysql/ry-vue.sql mysql:/tmp/

# 进入 MySQL 容器并导入
docker exec -i mysql mysql -uroot -proot123456 ry-vue < mysql/ry-vue.sql
```

### 3. 配置后端应用

编辑 `ruoyi-admin/src/main/resources/application.yml`:

```yaml
spring:
  datasource:
    url: jdbc:mysql://mysql:3306/ry-vue?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=true&serverTimezone=GMT%2B8
    username: root
    password: root123456
  redis:
    host: redis
    port: 6379
```

### 4. 运行 Jenkins 构建

1. 在 Jenkins 中点击 `Build Now`
2. 查看构建日志
3. 等待构建完成

## 访问应用

部署成功后，可以通过以下地址访问：

- **前端**: http://<服务器IP>:80
- **后端 API**: http://<服务器IP>:8080
- **Swagger 文档**: http://<服务器IP>:8080/swagger-ui/index.html

默认登录账号：
- 用户名: `admin`
- 密码: `admin123`

## 常见问题

### 1. Maven 构建失败
- 检查 Maven 版本是否为 3.9.x
- 检查网络连接，确保能访问 Maven 仓库
- 检查 JDK 版本是否为 8

### 2. Node.js 构建失败
- 检查 Node.js 版本是否为 18.x
- 检查 npm 镜像源配置
- 清理 npm 缓存: `npm cache clean --force`

### 3. Docker 构建失败
- 检查 Jenkins 用户是否有 Docker 权限
- 检查 Docker 服务是否运行
- 检查 Dockerfile 语法是否正确

### 4. 容器启动失败
- 查看容器日志: `docker logs <容器名>`
- 检查端口是否被占用
- 检查网络配置是否正确

### 5. 前后端无法通信
- 检查容器是否在同一网络中
- 检查 nginx 配置中的 proxy_pass 地址
- 检查后端容器是否正常运行

## 维护操作

### 查看容器状态
```bash
docker ps
docker ps -a
```

### 查看容器日志
```bash
docker logs ruoyi-backend
docker logs ruoyi-frontend
```

### 重启容器
```bash
docker restart ruoyi-backend
docker restart ruoyi-frontend
```

### 停止容器
```bash
docker stop ruoyi-backend
docker stop ruoyi-frontend
```

### 删除容器
```bash
docker rm -f ruoyi-backend
docker rm -f ruoyi-frontend
```

### 清理未使用的镜像
```bash
docker image prune -a
```

## 安全建议

1. **修改默认密码**: 部署后立即修改数据库和应用的默认密码
2. **配置 HTTPS**: 在生产环境中使用 HTTPS
3. **防火墙配置**: 只开放必要的端口
4. **定期备份**: 定期备份数据库和重要文件
5. **更新依赖**: 定期更新依赖包以修复安全漏洞

## 性能优化

1. **使用多阶段构建**: 减少 Docker 镜像大小
2. **配置资源限制**: 限制容器资源使用
3. **使用缓存**: 利用 Maven 和 npm 缓存加速构建
4. **并行构建**: 前后端可以并行构建
5. **使用 CDN**: 静态资源可以使用 CDN 加速

## 监控和日志

### 应用日志
- 后端日志: `${WORKSPACE}/logs/`
- 容器日志: `docker logs <容器名>`

### 监控工具
- Prometheus + Grafana
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Jenkins 内置日志

## 回滚操作

如果新版本部署失败，可以回滚到之前的版本：

```bash
# 停止当前容器
docker stop ruoyi-backend
docker stop ruoyi-frontend

# 删除当前容器
docker rm ruoyi-backend
docker rm ruoyi-frontend

# 启动旧版本容器
docker run -d --name ruoyi-backend --network ruoyi-net -p 8080:8080 ruoyi-backend:<旧版本标签>
docker run -d --name ruoyi-frontend --network ruoyi-net -p 80:80 ruoyi-frontend:<旧版本标签>
```

## 联系支持

如有问题，请联系：
- 项目地址: https://github.com/John98k/ry
- 若依官网: http://www.ruoyi.vip
