#!/bin/bash

# 若依项目快速部署脚本

set -e

echo "========================================="
echo "若依项目快速部署脚本"
echo "========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker 未安装${NC}"
        echo "请先安装 Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker 已安装${NC}"
}

# 检查 Docker Compose 是否安装
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}警告: Docker Compose 未安装${NC}"
        echo "请先安装 Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Compose 已安装${NC}"
}

# 创建网络
create_network() {
    if ! docker network ls | grep -q ruoyi-net; then
        docker network create ruoyi-net
        echo -e "${GREEN}✓ 创建 Docker 网络 ruoyi-net${NC}"
    else
        echo -e "${GREEN}✓ Docker 网络 ruoyi-net 已存在${NC}"
    fi
}

# 启动依赖服务
start_dependencies() {
    echo ""
    echo "========================================="
    echo "启动依赖服务 (MySQL, Redis)"
    echo "========================================="
    
    docker-compose up -d mysql redis
    
    echo -e "${GREEN}✓ 依赖服务启动中...${NC}"
    echo "等待 MySQL 启动..."
    sleep 15
    
    echo -e "${GREEN}✓ 依赖服务启动完成${NC}"
}

# 构建后端
build_backend() {
    echo ""
    echo "========================================="
    echo "构建后端服务"
    echo "========================================="
    
    # 检查 Maven 是否安装
    if ! command -v mvn &> /dev/null; then
        echo -e "${RED}错误: Maven 未安装${NC}"
        exit 1
    fi
    
    # Maven 编译
    echo "正在编译后端代码..."
    mvn clean install -DskipTests
    
    # 构建 Docker 镜像
    echo "正在构建后端 Docker 镜像..."
    docker build -t ruoyi-backend:latest .
    
    echo -e "${GREEN}✓ 后端构建完成${NC}"
}

# 构建前端
build_frontend() {
    echo ""
    echo "========================================="
    echo "构建前端服务"
    echo "========================================="
    
    # 检查 Node.js 是否安装
    if ! command -v node &> /dev/null; then
        echo -e "${RED}错误: Node.js 未安装${NC}"
        exit 1
    fi
    
    cd ruoyi-ui
    
    # 安装依赖
    echo "正在安装前端依赖..."
    npm install --registry=https://registry.npmmirror.com
    
    # 构建生产版本
    echo "正在构建前端代码..."
    npm run build:prod
    
    # 构建 Docker 镜像
    echo "正在构建前端 Docker 镜像..."
    docker build -t ruoyi-frontend:latest .
    
    cd ..
    
    echo -e "${GREEN}✓ 前端构建完成${NC}"
}

# 部署应用
deploy_app() {
    echo ""
    echo "========================================="
    echo "部署应用"
    echo "========================================="
    
    # 停止旧容器
    echo "停止旧容器..."
    docker-compose stop ruoyi-backend ruoyi-frontend || true
    docker-compose rm -f ruoyi-backend ruoyi-frontend || true
    
    # 启动新容器
    echo "启动新容器..."
    docker-compose up -d ruoyi-backend ruoyi-frontend
    
    echo -e "${GREEN}✓ 应用部署完成${NC}"
}

# 健康检查
health_check() {
    echo ""
    echo "========================================="
    echo "健康检查"
    echo "========================================="
    
    echo "等待服务启动..."
    sleep 30
    
    # 检查容器状态
    echo ""
    echo "容器状态:"
    docker-compose ps
    
    # 检查服务健康状态
    echo ""
    echo "服务健康检查:"
    
    if curl -f http://localhost:8080 &> /dev/null; then
        echo -e "${GREEN}✓ 后端服务正常${NC}"
    else
        echo -e "${RED}✗ 后端服务异常${NC}"
    fi
    
    if curl -f http://localhost:80 &> /dev/null; then
        echo -e "${GREEN}✓ 前端服务正常${NC}"
    else
        echo -e "${RED}✗ 前端服务异常${NC}"
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "========================================="
    echo "部署完成！"
    echo "========================================="
    echo ""
    echo "访问地址:"
    echo "  前端: http://localhost:80"
    echo "  后端: http://localhost:8080"
    echo "  API: http://localhost:80/prod-api/"
    echo "  Swagger: http://localhost:8080/swagger-ui/index.html"
    echo ""
    echo "默认登录账号:"
    echo "  用户名: admin"
    echo "  密码: admin123"
    echo ""
    echo "常用命令:"
    echo "  查看日志: docker-compose logs -f"
    echo "  查看状态: docker-compose ps"
    echo "  停止服务: docker-compose stop"
    echo "  启动服务: docker-compose start"
    echo "  重启服务: docker-compose restart"
    echo ""
}

# 主函数
main() {
    check_docker
    check_docker_compose
    create_network
    
    # 解析命令行参数
    case "${1:-all}" in
        all)
            start_dependencies
            build_backend
            build_frontend
            deploy_app
            health_check
            show_access_info
            ;;
        backend)
            build_backend
            deploy_app
            health_check
            show_access_info
            ;;
        frontend)
            build_frontend
            deploy_app
            health_check
            show_access_info
            ;;
        deploy)
            deploy_app
            health_check
            show_access_info
            ;;
        *)
            echo "用法: $0 [all|backend|frontend|deploy]"
            echo ""
            echo "选项:"
            echo "  all      - 构建并部署前后端 (默认)"
            echo "  backend  - 仅构建并部署后端"
            echo "  frontend - 仅构建并部署前端"
            echo "  deploy   - 仅部署已构建的镜像"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
