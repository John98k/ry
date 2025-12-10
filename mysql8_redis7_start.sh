#!/bin/bash
set -e  # 脚本执行出错时立即退出

# ===================== 自定义配置项（根据需求修改）=====================
# ---------------------- MySQL 配置 ----------------------
MYSQL_CONTAINER="my_mysql8"       # MySQL容器名
MYSQL_PORT="3306"                # MySQL宿主机端口
MYSQL_ROOT_PWD="MyRoot@123456"   # MySQL root密码
MYSQL_IMAGE_TAG="8"         # MySQL镜像标签（和已拉取的一致）
MYSQL_DATA_DIR="/Users/zlong/IdeaProjects/RuoYi-Vue/mysql/data"      # 数据持久化目录（避免容器删除数据丢失）
INIT_SQL_FILE="/Users/zlong/IdeaProjects/RuoYi-Vue/sql/ry_20250522.sql"  # 初始化SQL文件路径（关键！）

# ---------------------- Redis 7 配置 ----------------------
REDIS_CONTAINER="my_redis7"      # Redis7容器名
REDIS_PORT="6379"                # Redis宿主机端口
REDIS_PASSWORD="MyRedis@123456"  # Redis密码（建议设置，避免无密码访问）
REDIS_IMAGE_TAG="7-alpine"       # Redis7镜像标签（alpine版体积更小）
REDIS_DATA_DIR="/Users/zlong/IdeaProjects/RuoYi-Vue/redis/data"    # Redis数据持久化目录
REDIS_CONF_DIR="/Users/zlong/IdeaProjects/RuoYi-Vue/redis/conf"    # Redis配置目录（可选）
# ========================================================================

# ===================== 通用函数：检查并删除同名容器 =====================
remove_exist_container() {
    local container_name=$1
    if docker ps -a --filter "name=${container_name}" --format "{{.Names}}" | grep -q "${container_name}"; then
        echo "⚠️  发现同名容器${container_name}，先停止并删除..."
        docker stop ${container_name} >/dev/null 2>&1
        docker rm ${container_name} >/dev/null 2>&1
    fi
}

# ===================== MySQL 启动逻辑 =====================
echo "========== 开始启动 MySQL =========="
# 1. 检查MySQL初始化SQL文件
if [ ! -f "${INIT_SQL_FILE}" ]; then
    read -p "❌ MySQL初始化SQL文件${INIT_SQL_FILE}不存在，是否继续启动MySQL？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 终止MySQL启动，脚本继续执行Redis启动..."
    else
        # 创建MySQL数据目录
        mkdir -p "${MYSQL_DATA_DIR}"
        echo "✅ 已创建MySQL数据目录：${MYSQL_DATA_DIR}"

        # 检查并删除同名MySQL容器
        remove_exist_container ${MYSQL_CONTAINER}

        # 启动MySQL容器
        echo "🚀 启动MySQL容器(${MYSQL_CONTAINER})..."
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

        # 检查MySQL启动状态
        sleep 8
        if docker ps --filter "name=${MYSQL_CONTAINER}" --format "{{.Names}}" | grep -q "${MYSQL_CONTAINER}"; then
            echo "🎉 MySQL容器启动成功！端口：${MYSQL_PORT}，密码：${MYSQL_ROOT_PWD}"
        else
            echo "❌ MySQL容器启动失败！日志："
            docker logs ${MYSQL_CONTAINER} | tail -10
        fi
    fi
else
    # SQL文件存在时直接启动
    mkdir -p "${MYSQL_DATA_DIR}"
    remove_exist_container ${MYSQL_CONTAINER}
    echo "🚀 启动MySQL容器(${MYSQL_CONTAINER})..."
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

    sleep 8
    if docker ps --filter "name=${MYSQL_CONTAINER}" --format "{{.Names}}" | grep -q "${MYSQL_CONTAINER}"; then
        echo "🎉 MySQL容器启动成功！端口：${MYSQL_PORT}，密码：${MYSQL_ROOT_PWD}"
    else
        echo "❌ MySQL容器启动失败！日志："
        docker logs ${MYSQL_CONTAINER} | tail -10
    fi
fi

# ===================== Redis 7 启动逻辑 =====================
echo -e "\n========== 开始启动 Redis 7 =========="
# 1. 创建Redis数据/配置目录
mkdir -p "${REDIS_DATA_DIR}" "${REDIS_CONF_DIR}"
echo "✅ 已创建Redis目录：数据=${REDIS_DATA_DIR}，配置=${REDIS_CONF_DIR}"

# 2. 生成Redis基础配置文件（可选，若目录为空则创建）
if [ -z "$(ls -A ${REDIS_CONF_DIR})" ]; then
    cat > "${REDIS_CONF_DIR}/redis.conf" << EOF
# 允许远程访问
bind 0.0.0.0
# 保护模式关闭（配合密码使用）
protected-mode no
# 设置密码
requirepass ${REDIS_PASSWORD}
# 持久化策略（RDB）
save 900 1
save 300 10
save 60 10000
# 数据文件存储路径
dir /data
# 日志级别
loglevel notice
# 时区
tz Asia/Shanghai
EOF
    echo "✅ 已生成Redis默认配置文件：${REDIS_CONF_DIR}/redis.conf"
fi

# 3. 检查并删除同名Redis容器
remove_exist_container ${REDIS_CONTAINER}

# 4. 启动Redis 7容器
echo "🚀 启动Redis 7容器(${REDIS_CONTAINER})..."
docker run -d \
  --name "${REDIS_CONTAINER}" \
  --restart=always \
  -p "${REDIS_PORT}:6379" \
  -v "${REDIS_DATA_DIR}:/data" \
  -v "${REDIS_CONF_DIR}/redis.conf:/etc/redis/redis.conf" \
  redis:"${REDIS_IMAGE_TAG}" \
  redis-server /etc/redis/redis.conf \
  --appendonly yes
# 开启AOF持久化（可选，增强数据可靠性）

# 5. 检查Redis启动状态
sleep 3
if docker ps --filter "name=${REDIS_CONTAINER}" --format "{{.Names}}" | grep -q "${REDIS_CONTAINER}"; then
    echo -e "\n🎉 全部启动完成！====================================="
    echo "MySQL：容器名=${MYSQL_CONTAINER} | 端口=${MYSQL_PORT} | 密码=${MYSQL_ROOT_PWD}"
    echo "Redis7：容器名=${REDIS_CONTAINER} | 端口=${REDIS_PORT} | 密码=${REDIS_PASSWORD}"
    echo -e "======================================================"
    echo -e "📌 常用命令："
    echo "  进入MySQL：docker exec -it ${MYSQL_CONTAINER} mysql -uroot -p${MYSQL_ROOT_PWD}"
    echo "  进入Redis：docker exec -it ${REDIS_CONTAINER} redis-cli -a ${REDIS_PASSWORD}"
    echo "  查看日志：docker logs ${MYSQL_CONTAINER} | docker logs ${REDIS_CONTAINER}"
else
    echo -e "\n❌ Redis 7容器启动失败！"
    echo "📄 错误日志（最后10行）："
    docker logs ${REDIS_CONTAINER} | tail -10
fi