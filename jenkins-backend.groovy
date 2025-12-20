pipeline {
    agent any

    tools {
        maven 'Maven 3.9'    // 请确保Jenkins全局工具配置中名称一致
    }

    environment {
        // 项目路径变量
        BACK_MODULE = "${WORKSPACE}/ruoyi-admin"
        
        // 镜像配置
        IMAGE_NAME = "ruoyi-backend"
        IMAGE_TAG = "latest"
        FULL_IMAGE_NAME = "${IMAGE_NAME}:${IMAGE_TAG}"
        
        // 容器配置
        CONTAINER_NAME = "ruoyi-backend"
        HOST_PORT = "8080"
        CONTAINER_PORT = "8080"
        NETWORK_NAME = "ruoyi-net"
        
        // 挂载日志目录（宿主机:容器）
        LOG_MOUNT = "${WORKSPACE}/logs:/home/ruoyi/logs"
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
                        sh "git --version"
                        // 在初始化阶段配置Git SSL/TLS设置，确保在所有Git操作前生效
                        sh "git config --list"
                        sh "git config --global --unset-all http.sslVersion"
                        sh "git config --global http.sslVersion tlsv1.2"
                        sh "git config --global --unset-all http.sslVerify"
                        sh "git config --global http.sslVerify false"
                        // 设置超时时间
                        sh "git config --global http.postBuffer 524288000"
                        sh "git config --global http.lowSpeedLimit 0"
                        sh "git config --global http.lowSpeedTime 999999"
                        sh "git config --list | grep http"
                    } catch (Exception e) {
                        echo "⚠️ 警告：找不到 git 命令或配置失败"
                    }

                    // 创建Docker网络
                    sh "docker network create ${NETWORK_NAME} || true"
                }
            }
        }

        stage('拉取代码') {
            steps {
                // 强制使用浅克隆 (Shallow Clone)，解决大文件传输中断问题
                checkout([
                    $class: 'GitSCM', 
                    branches: scm.branches, 
                    doGenerateSubmoduleConfigurations: false, 
                    extensions: [
                        [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: true]
                    ], 
                    submoduleCfg: [], 
                    userRemoteConfigs: scm.userRemoteConfigs
                ])
                
                // 调试：打印当前目录文件
                sh 'ls -al'
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

        stage('Docker部署') {
            steps {
                script {
                    echo '===== 构建后端镜像 ====='
                    // 使用根目录的Dockerfile构建
                    docker.build(FULL_IMAGE_NAME, "-f Dockerfile .")

                    echo '===== 清理旧容器 ====='
                    sh "docker stop ${CONTAINER_NAME} || true"
                    sh "docker rm ${CONTAINER_NAME} || true"

                    echo '===== 启动新容器 ====='
                    // 运行容器：加入网络，映射端口，挂载日志
                    sh """
                        docker run -d \
                        --name ${CONTAINER_NAME} \
                        --network ${NETWORK_NAME} \
                        --restart=always \
                        -p ${HOST_PORT}:${CONTAINER_PORT} \
                        -v ${LOG_MOUNT} \
                        ${FULL_IMAGE_NAME}
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ 后端部署成功！"
            echo "访问地址：http://<服务器IP>:${HOST_PORT}"
        }
        failure {
            echo "❌ 后端部署失败，请查看日志。"
        }
    }
}
