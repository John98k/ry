#!/bin/bash
# 脚本说明：启动MySQL容器并自动执行初始化SQL，仅首次启动执行SQL

# ===================== 自定义配置（根据自己需求修改）=====================
CONTAINER_NAME="mysql8"        # 容器名称（自定义）
MYSQL_PORT="3306"                # 宿主机映射端口（若被占用可改3307等）
MYSQL_ROOT_PWD="123456"          # root密码（务必修改！）
MYSQL_IMAGE_TAG="8"         # 镜像标签（如8.0、5.7，和你拉取的一致）
DATA_DIR="/Users/zlong/IdeaProjects/RuoYi-Vue/mysql/data"      # 数据持久化目录（避免容器删除数据丢失）
INIT_SQL_FILE="/Users/zlong/IdeaProjects/RuoYi-Vue/sql/ry_20250522.sql"  # 初始化SQL文件路径（关键！）
TIME_ZONE="Asia/Shanghai"        # 时区配置
# ========================================================================

# 1. 检查初始化SQL文件是否存在
if [ ! -f "${INIT_SQL_FILE}" ]; then
    echo "❌ 错误：初始化SQL文件 ${INIT_SQL_FILE} 不存在！"
    echo "请先创建该文件并写入初始化SQL（如建库、建表语句），再执行脚本。"
    exit 1
fi

# 2. 创建数据目录（避免挂载失败）
mkdir -p "${DATA_DIR}"
echo "✅ 已确保数据目录存在：${DATA_DIR}"

# 3. 停止并删除已存在的同名容器（避免冲突）
if docker ps -a | grep -q "${CONTAINER_NAME}"; then
    echo "⚠️  发现同名容器，先停止并删除..."
    docker stop "${CONTAINER_NAME}" >/dev/null 2>&1
    docker rm "${CONTAINER_NAME}" >/dev/null 2>&1
fi

# 4. 启动MySQL容器（核心：挂载初始化SQL到自动执行目录）
echo "🚀 启动MySQL容器..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${MYSQL_PORT}:3306" \
  -v "${DATA_DIR}:/var/lib/mysql" \
  -v "${INIT_SQL_FILE}:/docker-entrypoint-initdb.d/init.sql" \
  -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PWD}" \
  -e TZ="${TIME_ZONE}" \
  mysql:"${MYSQL_IMAGE_TAG}" \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_general_ci \
  --lower_case_table_names=1

# 5. 检查启动状态
sleep 8  # 首次启动需加载SQL，等待几秒
if docker ps | grep -q "${CONTAINER_NAME}"; then
    echo -e "\n🎉 MySQL容器启动成功！"
    echo "├─ 容器名称：${CONTAINER_NAME}"
    echo "├─ 访问地址：127.0.0.1:${MYSQL_PORT}"
    echo "├─ root密码：${MYSQL_ROOT_PWD}"
    echo "├─ 数据目录：${DATA_DIR}"
    echo "└─ 初始化SQL：${INIT_SQL_FILE}"
    echo -e "\n📌 常用命令："
    echo "  进入容器：docker exec -it ${CONTAINER_NAME} bash"
    echo "  登录MySQL：mysql -uroot -p${MYSQL_ROOT_PWD}"
    echo "  查看日志：docker logs ${CONTAINER_NAME}"
else
    echo -e "\n❌ MySQL容器启动失败！"
    echo "📄 错误日志（最后20行）："
    docker logs "${CONTAINER_NAME}" | tail -20
    exit 1
fi