pipeline {
    agent any

    tools {
        maven 'Maven 3.9'
        nodejs 'Node.js 18'
    }

    environment {
        BACKEND_DIR = "${WORKSPACE}/ruoyi-admin"
        FRONTEND_DIR = "${WORKSPACE}/ruoyi-ui"
        BACKEND_PORT = "8081"
        FRONTEND_PORT = "8082"
        BACKEND_PID_FILE = "${WORKSPACE}/backend.pid"
        FRONTEND_PID_FILE = "${WORKSPACE}/frontend.pid"
    }

    stages {
        stage('初始化') {
            steps {
                script {
                    echo '===== 环境初始化与检查 ====='
                    try {
                        sh "mvn -v"
                    } catch (Exception e) {
                        echo "⚠️ 警告：找不到 mvn 命令"
                    }
                    try {
                        sh "node -v"
                        sh "npm -v"
                    } catch (Exception e) {
                        echo "⚠️ 警告：找不到 node 或 npm 命令"
                    }
                    try {
                        sh "git --version"
                        sh "git config --global http.sslVersion tlsv1.2"
                        sh "git config --global http.sslVerify false"
                        sh "git config --global http.postBuffer 524288000"
                    } catch (Exception e) {
                        echo "⚠️ 警告：找不到 git 命令或配置失败"
                    }
                }
            }
        }

        stage('拉取代码') {
            steps {
                script {
                    echo '===== 拉取代码 ====='
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
                    sh 'ls -al'
                }
            }
        }

        stage('停止旧进程') {
            steps {
                script {
                    echo '===== 停止旧进程 ====='
                    sh """
                        if [ -f \\${BACKEND_PID_FILE} ]; then
                            PID=\\$(cat \\${BACKEND_PID_FILE})
                            if ps -p \\$PID > /dev/null 2>&1; then
                                echo "停止后端进程: \\$PID"
                                kill \\$PID || true
                                sleep 3
                            fi
                            rm -f \\${BACKEND_PID_FILE}
                        fi
                        lsof -ti:\\${BACKEND_PORT} | xargs kill -9 2>/dev/null || true
                    """
                    sh """
                        if [ -f \\${FRONTEND_PID_FILE} ]; then
                            PID=\\$(cat \\${FRONTEND_PID_FILE})
                            if ps -p \\$PID > /dev/null 2>&1; then
                                echo "停止前端进程: \\$PID"
                                kill \\$PID || true
                                sleep 3
                            fi
                            rm -f \\${FRONTEND_PID_FILE}
                        fi
                        lsof -ti:\\${FRONTEND_PORT} | xargs kill -9 2>/dev/null || true
                    """
                }
            }
        }

        stage('编译后端') {
            steps {
                script {
                    echo '===== 编译后端项目 ====='
                    dir("\${WORKSPACE}") {
                        sh "mvn clean install -DskipTests"
                    }
                }
            }
        }

        stage('启动后端') {
            steps {
                script {
                    echo '===== 启动后端项目 ====='
                    dir("\\${WORKSPACE}") {
                        sh """
                            nohup mvn spring-boot:run > \\${WORKSPACE}/backend.log 2>&1 &
                            echo \\$! > \\${BACKEND_PID_FILE}
                            echo "后端进程ID: \\$(cat \\${BACKEND_PID_FILE})"
                            echo "等待后端服务启动..."
                            sleep 30
                            if ps -p \\$(cat \\${BACKEND_PID_FILE}) > /dev/null 2>&1; then
                                echo "✅ 后端服务启动成功"
                            else
                                echo "❌ 后端服务启动失败，查看日志："
                                tail -50 \\${WORKSPACE}/backend.log
                                exit 1
                            fi
                        """
                    }
                }
            }
        }

        stage('编译前端') {
            steps {
                script {
                    echo '===== 编译前端项目 ====='
                    dir("\${FRONTEND_DIR}") {
                        sh "npm install --registry=https://registry.npmmirror.com"
                    }
                }
            }
        }

        stage('启动前端') {
            steps {
                script {
                    echo '===== 启动前端项目 ====='
                    dir("\\${FRONTEND_DIR}") {
                        sh """
                            nohup npm run dev > \\${WORKSPACE}/frontend.log 2>&1 &
                            echo \\$! > \\${FRONTEND_PID_FILE}
                            echo "前端进程ID: \\$(cat \\${FRONTEND_PID_FILE})"
                            echo "等待前端服务启动..."
                            sleep 20
                            if ps -p \\$(cat \\${FRONTEND_PID_FILE}) > /dev/null 2>&1; then
                                echo "✅ 前端服务启动成功"
                            else
                                echo "❌ 前端服务启动失败，查看日志："
                                tail -50 \\${WORKSPACE}/frontend.log
                                exit 1
                            fi
                        """
                    }
                }
            }
        }

        stage('验证服务') {
            steps {
                script {
                    echo '===== 验证服务状态 ====='
                    sh """
                        echo "检查后端服务 (端口 \\${BACKEND_PORT})..."
                        if lsof -i:\\${BACKEND_PORT} > /dev/null 2>&1; then
                            echo "✅ 后端服务正在监听端口 \\${BACKEND_PORT}"
                        else
                            echo "❌ 后端服务未监听端口 \\${BACKEND_PORT}"
                            echo "后端日志："
                            tail -30 \\${WORKSPACE}/backend.log
                        fi
                    """
                    sh """
                        echo "检查前端服务 (端口 \\${FRONTEND_PORT})..."
                        if lsof -i:\\${FRONTEND_PORT} > /dev/null 2>&1; then
                            echo "✅ 前端服务正在监听端口 \\${FRONTEND_PORT}"
                        else
                            echo "❌ 前端服务未监听端口 \\${FRONTEND_PORT}"
                            echo "前端日志："
                            tail -30 \\${WORKSPACE}/frontend.log
                        fi
                    """
                }
            }
        }
    }

    post {
        success {
            echo "========================================="
            echo "✅ 前后端项目启动成功！"
            echo "========================================="
            echo "后端访问地址：http://localhost:\\${BACKEND_PORT}"
            echo "前端访问地址：http://localhost:\\${FRONTEND_PORT}"
            echo "API文档地址：http://localhost:\\${BACKEND_PORT}/doc.html"
            echo "========================================="
            echo "进程ID文件："
            echo "  后端: \\${BACKEND_PID_FILE}"
            echo "  前端: \\${FRONTEND_PID_FILE}"
            echo "日志文件："
            echo "  后端: \\${WORKSPACE}/backend.log"
            echo "  前端: \\${WORKSPACE}/frontend.log"
            echo "========================================="
        }
        failure {
            echo "========================================="
            echo "❌ 项目启动失败，请查看日志"
            echo "========================================="
        }
        always {
            script {
                echo "========================================="
                echo "当前运行的进程："
                sh "ps aux | grep -E 'mvn|node|npm' | grep -v grep || echo '无相关进程'"
                echo "========================================="
            }
        }
    }
}
