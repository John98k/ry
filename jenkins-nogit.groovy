pipeline {
    agent any

    tools {
        maven 'Maven 3.9'    // 请确保Jenkins全局工具配置中名称一致
        nodejs 'Node.js 20'     // 请确保Jenkins全局工具配置中名称一致（用于前端构建）
    }

    environment {
        // 使用Jenkins内置变量 WORKSPACE
        BACK_MODULE = "${WORKSPACE}/ruoyi-admin"
        FRONT_DIR = "${WORKSPACE}/ruoyi-ui"

        // 镜像名称
        BACK_IMAGE = "ruoyi-backend:latest"
        FRONT_IMAGE = "ruoyi-frontend:latest"

        // 端口映射
        BACK_PORT = "8081"      // 后端端口（宿主:容器）
        FRONT_PORT = "80"        // 前端端口（宿主:容器）
        CONTAINER_PORT = "80"     // 前端容器内部端口（通常是Nginx默认的80端口）
        HOST_PORT = "8081"        // 后端访问端口（与BACK_PORT一致）

        // 挂载点
        LOG_MOUNT = "${WORKSPACE}/logs:/home/ruoyi/logs"  // 日志目录挂载

        // Docker网络名称（用于容器互通）
        NETWORK_NAME = "ruoyi-net"
        
        // 容器名称
        BACK_CONTAINER = "ruoyi-backend"  // 后端容器名称
        FRONT_CONTAINER = "ruoyi-frontend" // 前端容器名称
    }

    stages {
        stage('初始化') {
            steps {
                script {
                    echo '===== 环境初始化与检查 ====='
                    // 打印工具版本，确认命令是否存在
                    try {
                        sh "mvn -v"
                    } catch (Exception e) {
                        echo "⚠️ 警告：找不到 mvn 命令，请检查 Jenkins 全局工具配置名称是否为 'Maven 3.9'"
                    }
                    
                    try {
                        sh "docker -v"
                    } catch (Exception e) {
                        echo "⚠️ 警告：找不到 docker 命令，请检查 Jenkins 用户是否有 docker 权限"
                    }
                    try {
                        // 将本地项目文件复制到Jenkins工作空间
                        // 注意：假设Jenkins运行在名为"jenkins"的容器中，并且可以访问宿主机目录
                        // 如果Jenkins不是容器化运行的，此命令可能不需要
                        sh "docker cp /Users/zlong/IdeaProjects/RuoYi-Vue/ jenkins:/var/jenkins_home/workspace/ruoyi-nogit/"
                    } catch (Exception e) {
                        echo "⚠️ 警告：docker cp命令执行失败，请检查Jenkins容器名称和路径是否正确"
                    }
                    try {
                        // 验证文件是否复制成功（使用-d参数代替-it参数，因为Jenkins流水线没有交互终端）
                        sh "docker exec -d jenkins ls -l /var/jenkins_home/workspace/ruoyi-nogit/ruoyi-ui/package.json"
                    } catch (Exception e) {
                        echo "⚠️ 警告：docker exec命令执行失败，请检查Jenkins容器名称和路径是否正确"
                    }

                    // 创建Docker网络
                    sh "docker network create ${NETWORK_NAME} || true"
                }
            }
        }

        stage('Maven编译') {
            steps {
                script {
                    echo '===== 开始后端编译 ====='
                    // 在根目录执行install，确保子模块依赖正常
                    // -DskipTests 跳过测试
                    sh "mvn clean install -DskipTests"
                }
            }
        }

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
        stage('Docker后端部署') {
            steps {
                script {
                    echo '===== 构建后端镜像 ====='
                    // 使用根目录的Dockerfile构建
                    docker.build("${BACK_IMAGE}", "-f Dockerfile .")

                    echo '===== 清理旧容器 ====='
                    sh "docker stop ${BACK_CONTAINER} || true"
                    sh "docker rm ${BACK_CONTAINER} || true"

                    echo '===== 启动新容器 ====='
                    // 运行容器：加入网络，映射端口，挂载日志
                    sh """
                        docker run -d \
                        --name ${BACK_CONTAINER} \
                        --network ${NETWORK_NAME} \
                        --restart=always \
                        -p ${BACK_PORT}:8081 \
                        -v ${LOG_MOUNT} \
                        ${BACK_IMAGE}
                    """
                }
            }
        }
        stage('Docker前端部署') {
            steps {
                script {
                    echo '===== 构建前端镜像 ====='
                    // 进入前端目录构建，使用该目录下的Dockerfile
                    dir("${FRONT_DIR}") {
                        docker.build("${FRONT_IMAGE}", ".")
                    }

                    echo '===== 清理旧容器 ====='
                    sh "docker stop ${FRONT_CONTAINER} || true"
                    sh "docker rm ${FRONT_CONTAINER} || true"

                    echo '===== 启动新容器 ====='
                    // 运行容器：加入网络，映射端口
                    // 注意：前端Nginx配置中 proxy_pass 需要指向后端容器名（如 ruoyi-backend）
                    sh """
                        docker run -d \
                        --name ${FRONT_CONTAINER} \
                        --network ${NETWORK_NAME} \
                        --restart=always \
                        -p ${FRONT_PORT}:${CONTAINER_PORT} \
                        ${FRONT_IMAGE}
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ 前后端部署成功！"
            echo "后端访问地址：http://<服务器IP>:${HOST_PORT}"
            echo "前端访问地址：http://<服务器IP>:${FRONT_PORT}"
        }
        failure {
            echo "❌ 部署失败，请查看日志。"
        }
    }
}
