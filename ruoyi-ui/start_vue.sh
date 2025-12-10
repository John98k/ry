#!/bin/bash
set -e

# ========== 小白可改的配置（只改这里！）==========
VUE_CONTAINER_NAME="my_vue_app"  # 容器名字，随便改，比如vue_test
VUE_HOST_PORT="8000"             # 访问端口，8080被占用就改8081/8082
VUE_IMAGE_NAME="vue-app:latest"  # 镜像名字，不用改
# ==============================================

# 1. 停止并删除旧容器（避免冲突）
if docker ps -a --filter "name=${VUE_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "${VUE_CONTAINER_NAME}"; then
    echo "⚠️  发现旧容器，先停止删除..."
    docker stop ${VUE_CONTAINER_NAME} >/dev/null 2>&1
    docker rm ${VUE_CONTAINER_NAME} >/dev/null 2>&1
fi

# 2. 构建Vue镜像（耐心等，第一次会下载依赖）
echo "🚀 开始构建Vue镜像（第一次可能慢，别关！）..."
docker build -t ${VUE_IMAGE_NAME} .

# 3. 启动容器
echo "🚀 启动Vue项目容器..."
docker run -d \
  --name ${VUE_CONTAINER_NAME} \
  --restart=always \
  -p ${VUE_HOST_PORT}:80 \
  ${VUE_IMAGE_NAME}

# 4. 检查是否启动成功
sleep 3
if docker ps --filter "name=${VUE_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "${VUE_CONTAINER_NAME}"; then
    echo -e "\n🎉 启动成功！！！"
    echo "👉 访问地址：http://localhost:${VUE_HOST_PORT}"
    echo "如果打不开，检查端口是否被占用，改上面的VUE_HOST_PORT就行"
else
    echo -e "\n❌ 启动失败！错误日志："
    docker logs ${VUE_CONTAINER_NAME}
    exit 1
fi
