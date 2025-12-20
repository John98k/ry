pipeline {
    agent any

    tools {
        nodejs 'Node.js 18',
        maven 'Maven 3.9'  // 请确保Jenkins全局工具配置中名称一致
    }

    environment {
        // 项目路径变量
        FRONT_DIR = "${WORKSPACE}/ruoyi-ui"
        
        // 镜像配置
        IMAGE_NAME = "ruoyi-frontend"
        IMAGE_TAG = "latest"
        FULL_IMAGE_NAME = "${IMAGE_NAME}:${IMAGE_TAG}"
        
        // 容器配置
        CONTAINER_NAME = "ruoyi-frontend"
        HOST_PORT = "80"
        CONTAINER_PORT = "80"
        NETWORK_NAME = "ruoyi-net"
    }

    stages {

        stage('Node编译') {
            steps {
                script {
                    echo '===== 开始前端编译 ====='
                    dir("${FRONT_DIR}") {
                        // 使用淘宝镜像源加速
                        sh "npm install --registry=https://registry.npmmirror.com"
                        sh "npm run build"
                    }
                }
            }
        }

        stage('Docker部署') {
            steps {
                script {
                    echo '===== 构建前端镜像 ====='
                    // 进入前端目录构建，使用该目录下的Dockerfile
                    dir("${FRONT_DIR}") {
                        docker.build(FULL_IMAGE_NAME, ".")
                    }

                    echo '===== 清理旧容器 ====='
                    sh "docker stop ${CONTAINER_NAME} || true"
                    sh "docker rm ${CONTAINER_NAME} || true"

                    echo '===== 启动新容器 ====='
                    // 运行容器：加入网络，映射端口
                    // 注意：前端Nginx配置中 proxy_pass 需要指向后端容器名（如 ruoyi-backend）
                    sh """
                        docker run -d \
                        --name ${CONTAINER_NAME} \
                        --network ${NETWORK_NAME} \
                        --restart=always \
                        -p ${HOST_PORT}:${CONTAINER_PORT} \
                        ${FULL_IMAGE_NAME}
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ 前端部署成功！"
            echo "访问地址：http://<服务器IP>:${HOST_PORT}"
        }
        failure {
            echo "❌ 前端部署失败，请查看日志。"
        }
    }
}
