#!/bin/bash

# ===================== 自定义配置项（和启动脚本保持一致）=====================
MYSQL_CONTAINER="my_mysql8"
REDIS_CONTAINER="my_redis7"
# =====================================================================

# 询问是否删除容器（仅停止则保留容器，下次可直接start）
read -p "❓ 是否删除容器？仅停止请选n，删除请选y (y/n): " -n 1 -r
echo

# ---------------------- 停止容器 ----------------------
echo "========== 停止容器 =========="
# 停止MySQL
if docker ps -a --filter "name=${MYSQL_CONTAINER}" --format "{{.Names}}" | grep -q "${MYSQL_CONTAINER}"; then
    echo "🛑 停止MySQL容器(${MYSQL_CONTAINER})..."
    docker stop ${MYSQL_CONTAINER} >/dev/null 2>&1
else
    echo "ℹ️  MySQL容器(${MYSQL_CONTAINER})不存在，无需停止"
fi

# 停止Redis
if docker ps -a --filter "name=${REDIS_CONTAINER}" --format "{{.Names}}" | grep -q "${REDIS_CONTAINER}"; then
    echo "🛑 停止Redis容器(${REDIS_CONTAINER})..."
    docker stop ${REDIS_CONTAINER} >/dev/null 2>&1
else
    echo "ℹ️  Redis容器(${REDIS_CONTAINER})不存在，无需停止"
fi

# ---------------------- 删除容器（可选）----------------------
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n========== 删除容器 =========="
    # 删除MySQL
    if docker ps -a --filter "name=${MYSQL_CONTAINER}" --format "{{.Names}}" | grep -q "${MYSQL_CONTAINER}"; then
        echo "🗑️ 删除MySQL容器(${MYSQL_CONTAINER})..."
        docker rm ${MYSQL_CONTAINER} >/dev/null 2>&1
    fi
    # 删除Redis
    if docker ps -a --filter "name=${REDIS_CONTAINER}" --format "{{.Names}}" | grep -q "${REDIS_CONTAINER}"; then
        echo "🗑️ 删除Redis容器(${REDIS_CONTAINER})..."
        docker rm ${REDIS_CONTAINER} >/dev/null 2>&1
    fi
    echo "✅ 容器已删除（数据目录仍保留：$HOME/mysql/data、$HOME/redis/data）"
else
    echo -e "\n✅ 容器已停止（未删除，可执行 docker start ${MYSQL_CONTAINER}/${REDIS_CONTAINER} 重启）"
fi

# ---------------------- 最终状态 ----------------------
echo -e "\n========== 当前容器状态 =========="
docker ps -a | grep -E "NAME|${MYSQL_CONTAINER}|${REDIS_CONTAINER}"