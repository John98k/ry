pipeline {
    agent any

    tools {
        maven 'Maven 3.9'
        nodejs 'Node.js 18'
    }

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

    stages {
        stage('初始化环境') {
            steps {
                script {
                    echo '===== 环境初始化与检查 ====='
                    
                    // 配置 Git 以解决 TLS 连接问题
                    sh "git config --global http.sslVersion tlsv1.2"
                    sh "git config --global http.sslVerify false"
                    sh "git config --global http.postBuffer 524288000"
                    
                    // 检查工具版本
                    sh "mvn -v || echo 'Maven 未安装'"
                    sh "node -v || echo 'Node.js 未安装'"
                    sh "npm -v || echo 'npm 未安装'"
                    sh "docker -v || echo 'Docker 未安装'"
                    
                    // 创建 Docker 网络
                    sh "docker network create ${NETWORK_NAME} || true"
                    
                    // 创建日志目录
                    sh "mkdir -p ${WORKSPACE}/logs"
                }
            }
        }

        stage('拉取代码') {
            steps {
                script {
                    echo '===== 拉取代码 ====='
                    checkout([
                        $class: 'GitSCM', 
                        branches: [[name: '*/master']], 
                        doGenerateSubmoduleConfigurations: false, 
                        extensions: [
                            [$class: 'CloneOption', depth: 1, noTags: false, shallow: true]
                        ], 
                        submoduleCfg: [], 
                        userRemoteConfigs: [[url: 'https://github.com/John98k/ry.git']]
                    ])
                    
                    sh 'ls -la'
                }
            }
        }

        stage('构建后端') {
            steps {
                script {
                    echo '===== 开始后端编译 ====='
                    
                    // Maven 编译打包
                    sh "mvn clean install -DskipTests"
                    
                    echo '===== 构建后端 Docker 镜像 ====='
                    
                    // 检查 Dockerfile
                    sh "test -f Dockerfile || exit 1"
                    
                    // 构建镜像
                    sh "docker build -t ${BACKEND_IMAGE}:latest ."
                    
                    echo '===== 部署后端容器 ====='
                    
                    // 停止并删除旧容器
                    sh "docker stop ${BACKEND_CONTAINER} || true"
                    sh "docker rm ${BACKEND_CONTAINER} || true"
                    
                    // 启动新容器
                    sh """
                        docker run -d \
                        --name ${BACKEND_CONTAINER} \
                        --network ${NETWORK_NAME} \
                        --restart=always \
                        -p ${BACKEND_PORT}:8080 \
                        -v ${LOG_MOUNT} \
                        ${BACKEND_IMAGE}:latest
                    """
                }
            }
        }

        stage('构建前端') {
            steps {
                script {
                    echo '===== 开始前端编译 ====='
                    
                    dir("ruoyi-ui") {
                        // 安装依赖
                        sh "npm install --registry=https://registry.npmmirror.com"
                        
                        // 构建生产版本
                        sh "npm run build:prod"
                        
                        echo '===== 构建前端 Docker 镜像 ====='
                        
                        // 检查 Dockerfile 和 nginx.conf
                        sh "test -f Dockerfile || exit 1"
                        sh "test -f nginx.conf || exit 1"
                        
                        // 构建镜像
                        sh "docker build -t ${FRONTEND_IMAGE}:latest ."
                    }
                    
                    echo '===== 部署前端容器 ====='
                    
                    // 停止并删除旧容器
                    sh "docker stop ${FRONTEND_CONTAINER} || true"
                    sh "docker rm ${FRONTEND_CONTAINER} || true"
                    
                    // 启动新容器
                    sh """
                        docker run -d \
                        --name ${FRONTEND_CONTAINER} \
                        --network ${NETWORK_NAME} \
                        --restart=always \
                        -p ${FRONTEND_PORT}:80 \
                        ${FRONTEND_IMAGE}:latest
                    """
                }
            }
        }

        stage('健康检查') {
            steps {
                script {
                    echo '===== 等待服务启动 ====='
                    sleep 30
                    
                    echo '===== 检查容器状态 ====='
                    sh "docker ps | grep ${BACKEND_CONTAINER}"
                    sh "docker ps | grep ${FRONTEND_CONTAINER}"
                    
                    echo '===== 检查服务健康状态 ====='
                    sh "curl -f http://localhost:${BACKEND_PORT} || echo '后端服务检查失败'"
                    sh "curl -f http://localhost:${FRONTEND_PORT} || echo '前端服务检查失败'"
                }
            }
        }
    }

    post {
        success {
            echo '✅ 部署成功！'
            echo "后端访问地址：http://<服务器IP>:${BACKEND_PORT}"
            echo "前端访问地址：http://<服务器IP>:${FRONTEND_PORT}"
            echo "API 地址：http://<服务器IP>:${FRONTEND_PORT}/prod-api/"
        }
        failure {
            echo '❌ 部署失败，请查看日志！'
            sh "docker logs ${BACKEND_CONTAINER} || echo '无法获取后端日志'"
            sh "docker logs ${FRONTEND_CONTAINER} || echo '无法获取前端日志'"
        }
        always {
            echo '===== 清理构建缓存 ====='
            sh "docker system prune -f || true"
        }
    }
}
