# 若依项目 Jenkins 部署快速开始指南

## 快速开始

### 方式一：使用 Docker Compose（推荐）

1. **克隆项目**
   ```bash
   git clone https://github.com/John98k/ry.git
   cd ry
   ```

2. **一键部署**
   ```bash
   ./deploy.sh
   ```

3. **访问应用**
   - 前端: http://localhost:80
   - 后端: http://localhost:8080
   - 默认账号: admin / admin123

### 方式二：使用 Jenkins

1. **安装 Jenkins**
   ```bash
   # Ubuntu/Debian
   wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
   sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
   sudo apt update && sudo apt install jenkins
   sudo systemctl start jenkins
   ```

2. **配置 Jenkins**
   - 访问 http://localhost:8080
   - 按照提示完成初始化
   - 安装推荐插件

3. **创建 Pipeline 任务**
   - 新建 Pipeline 任务
   - 配置 Git 仓库: https://github.com/John98k/ry.git
   - 选择 Pipeline script from SCM
   - Script Path: Jenkinsfile

4. **构建项目**
   - 点击 "Build Now"
   - 等待构建完成

## 项目结构

```
RuoYi-Vue/
├── ruoyi-admin/          # 后端主模块
├── ruoyi-common/         # 通用模块
├── ruoyi-framework/      # 框架核心
├── ruoyi-generator/      # 代码生成
├── ruoyi-quartz/         # 定时任务
├── ruoyi-system/         # 系统模块
├── ruoyi-ui/             # 前端项目
├── Dockerfile            # 后端 Docker 镜像
├── Jenkinsfile           # Jenkins Pipeline 配置
├── docker-compose.yml    # Docker Compose 配置
├── deploy.sh             # 快速部署脚本
└── JENKINS_DEPLOY.md     # 详细部署文档
```

## 技术栈

### 后端
- Spring Boot 2.5.15
- Spring Security 5.7.14
- MyBatis
- MySQL 8.0
- Redis 7.0
- Swagger 3.0.0
- Knife4j 3.0.3

### 前端
- Vue 2.6.12
- Element UI 2.15.14
- Vue Router 3.4.9
- Vuex 3.6.0
- Axios 0.28.1
- ECharts 5.4.0

### 部署
- Docker
- Docker Compose
- Jenkins
- Nginx

## 常用命令

### Docker Compose
```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose stop

# 重启所有服务
docker-compose restart

# 查看日志
docker-compose logs -f

# 查看服务状态
docker-compose ps

# 删除所有容器
docker-compose down
```

### 部署脚本
```bash
# 完整部署（前后端）
./deploy.sh

# 仅部署后端
./deploy.sh backend

# 仅部署前端
./deploy.sh frontend

# 仅部署已构建的镜像
./deploy.sh deploy
```

### Docker
```bash
# 查看运行中的容器
docker ps

# 查看容器日志
docker logs ruoyi-backend
docker logs ruoyi-frontend

# 进入容器
docker exec -it ruoyi-backend sh
docker exec -it ruoyi-frontend sh

# 重启容器
docker restart ruoyi-backend
docker restart ruoyi-frontend
```

## 配置说明

### 后端配置

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

### 前端配置

编辑 `ruoyi-ui/.env.production`:

```bash
VUE_APP_BASE_API = '/prod-api'
```

编辑 `ruoyi-ui/nginx.conf`:

```nginx
location /prod-api/ {
    proxy_pass http://ruoyi-backend:8080/;
}
```

## 故障排查

### 后端无法启动
1. 检查 MySQL 和 Redis 是否正常运行
   ```bash
   docker ps | grep mysql
   docker ps | grep redis
   ```

2. 查看后端日志
   ```bash
   docker logs ruoyi-backend
   ```

3. 检查数据库连接
   ```bash
   docker exec -it mysql mysql -uroot -proot123456 -e "SHOW DATABASES;"
   ```

### 前端无法访问
1. 检查前端容器是否运行
   ```bash
   docker ps | grep ruoyi-frontend
   ```

2. 查看前端日志
   ```bash
   docker logs ruoyi-frontend
   ```

3. 检查 Nginx 配置
   ```bash
   docker exec -it ruoyi-frontend cat /etc/nginx/conf.d/default.conf
   ```

### 前后端无法通信
1. 检查容器是否在同一网络
   ```bash
   docker network inspect ruoyi-net
   ```

2. 检查后端服务是否正常
   ```bash
   curl http://localhost:8080
   ```

3. 检查 Nginx 代理配置
   ```bash
   docker exec -it ruoyi-frontend nginx -t
   ```

## 性能优化

### 后端优化
- 增加 JVM 内存: 在 Dockerfile 中添加 `JAVA_OPTS`
- 配置数据库连接池: 调整 Druid 配置
- 启用 Redis 缓存: 合理使用缓存

### 前端优化
- 启用 Gzip 压缩: 在 nginx.conf 中配置
- 使用 CDN: 静态资源使用 CDN 加速
- 代码分割: 使用 Vue Router 懒加载

### Docker 优化
- 使用多阶段构建: 减少 Docker 镜像大小
- 配置资源限制: 限制容器资源使用
- 使用健康检查: 确保服务正常运行

## 安全建议

1. **修改默认密码**
   - 数据库 root 密码
   - 应用管理员密码
   - Redis 密码（如果需要）

2. **配置 HTTPS**
   - 使用 Let's Encrypt 免费证书
   - 配置 Nginx SSL

3. **防火墙配置**
   - 只开放必要的端口
   - 限制访问来源

4. **定期备份**
   - 数据库备份
   - 配置文件备份
   - 应用日志备份

5. **更新依赖**
   - 定期更新依赖包
   - 修复安全漏洞

## 监控和日志

### 应用日志
- 后端日志: `./logs/`
- 容器日志: `docker logs <容器名>`

### 监控工具
- Prometheus + Grafana
- ELK Stack
- Jenkins 内置日志

## 更多信息

- **详细部署文档**: [JENKINS_DEPLOY.md](JENKINS_DEPLOY.md)
- **项目地址**: https://github.com/John98k/ry
- **若依官网**: http://www.ruoyi.vip
- **若依文档**: http://doc.ruoyi.vip

## 联系方式

如有问题，请提交 Issue 或联系项目维护者。
