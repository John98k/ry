#!/bin/bash
set -e  # 出错立即退出

# ===================== 自定义配置项（按需修改）=====================
# MySQL配置
MYSQL_CONTAINER="my_mysql8"
MYSQL_PORT="3306"
MYSQL_ROOT_PWD="MyRoot@123456"
MYSQL_IMAGE_TAG="8"
MYSQL_DATA_DIR="$HOME/mysql/data"
INIT_SQL_FILE="$HOME/mysql/init.sql"

# Redis 7配置
REDIS_CONTAINER="my_redis7"
REDIS_PORT="6379"
REDIS_PASSWORD="MyRedis@123456"
REDIS_IMAGE_TAG="7-alpine"
REDIS_DATA_DIR="$HOME/redis/data"
REDIS_CONF_DIR="$HOME/redis/conf"
# =====================================================================

# 通用函数1：启动已存在的容器
start_exist_container() {
    local container_name=$1
    # 检查容器是否存在
    if docker ps -a --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
        # 检查容器是否已运行
        if docker ps --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
            echo "✅ ${container_name} 容器已在运行，无需操作"
        else
            echo "🚀 启动已存在的 ${container_name} 容器..."
            docker start ${container_name} >/dev/null 2>&1
            echo "✅ ${container_name} 容器启动成功"
        fi
    else
        return 1  # 容器不存在，返回1
    fi
}

# 通用函数2：新建容器（仅容器不存在时执行）
create_new_container() {
    local container_type=$1
    if [ "${container_type}" = "mysql" ]; then
        echo "⚠️  ${MYSQL_CONTAINER} 容器不存在，开始新建并启动..."
        # 创建MySQL数据目录
        mkdir -p "${MYSQL_DATA_DIR}"
        # 检查SQL文件（不存在则提示）
        if [ ! -f "${INIT_SQL_FILE}" ]; then
            echo "⚠️  MySQL初始化SQL文件${INIT_SQL_FILE}不存在，将启动空MySQL容器"
        fi
        # 新建MySQL容器
        docker run -d \
          --name "${MYSQL_CONTAINER}" \
          --restart=always \
          -p "${MYSQL_PORT}:3306" \
          -v "${MYSQL_DATA_DIR}:/var/lib/mysql" \
          -v "${INIT_SQL_FILE}:/docker-entrypoint-initdb.d/init.sql" \
          -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PWD}" \
          -e TZ="Asia/Shanghai" \
          mysql:"${MYSQL_IMAGE_TAG}" \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_general_ci \
          --lower_case_table_names=1
        echo "✅ ${MYSQL_CONTAINER} 容器新建并启动成功"
    elif [ "${container_type}" = "redis" ]; then
        echo "⚠️  ${REDIS_CONTAINER} 容器不存在，开始新建并启动..."
        # 创建Redis目录
        mkdir -p "${REDIS_DATA_DIR}" "${REDIS_CONF_DIR}"
        # 生成Redis配置（移除tz指令，避免兼容问题）
        if [ -z "$(ls -A ${REDIS_CONF_DIR})" ]; then
            cat > "${REDIS_CONF_DIR}/redis.conf" << EOF
bind 0.0.0.0
protected-mode no
requirepass "${REDIS_PASSWORD}"
save 900 1
save 300 10
save 60 10000
dir /data
loglevel notice
appendonly yes
EOF
            echo "✅ 生成Redis配置文件：${REDIS_CONF_DIR}/redis.conf"
        fi
        # 新建Redis容器
        docker run -d \
          --name "${REDIS_CONTAINER}" \
          --restart=always \
          -p "${REDIS_PORT}:6379" \
          -v "${REDIS_DATA_DIR}:/data" \
          -v "${REDIS_CONF_DIR}/redis.conf:/etc/redis/redis.conf" \
          -e TZ="Asia/Shanghai" \
          redis:"${REDIS_IMAGE_TAG}" \
          redis-server /etc/redis/redis.conf
        echo "✅ ${REDIS_CONTAINER} 容器新建并启动成功"
    fi
}

# ---------------------- 处理MySQL容器 ----------------------
echo "========== 处理MySQL容器 =========="
if ! start_exist_container ${MYSQL_CONTAINER}; then
    create_new_container "mysql"
fi

# ---------------------- 处理Redis容器 ----------------------
echo -e "\n========== 处理Redis容器 =========="
if ! start_exist_container ${REDIS_CONTAINER}; then
    create_new_container "redis"
fi

# ---------------------- 最终状态检查 ----------------------
echo -e "\n========== 容器最终状态 =========="
echo "容器名 | 状态 | 端口"
echo "-------------------------"
# 检查MySQL状态
MYSQL_STATUS=$(docker inspect --format '{{.State.Status}}' ${MYSQL_CONTAINER} 2>/dev/null || echo "不存在")
MYSQL_PORT_MAP=$(docker port ${MYSQL_CONTAINER} 3306 2>/dev/null || echo "-")
echo "${MYSQL_CONTAINER} | ${MYSQL_STATUS} | ${MYSQL_PORT_MAP}"

# 检查Redis状态
REDIS_STATUS=$(docker inspect --format '{{.State.Status}}' ${REDIS_CONTAINER} 2>/dev/null || echo "不存在")
REDIS_PORT_MAP=$(docker port ${REDIS_CONTAINER} 6379 2>/dev/null || echo "-")
echo "${REDIS_CONTAINER} | ${REDIS_STATUS} | ${REDIS_PORT_MAP}"

echo -e "\n🎉 操作完成！"