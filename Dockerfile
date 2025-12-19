# 基础镜像
FROM eclipse-temurin:8-jre-alpine

# 作者
MAINTAINER ruoyi

# 挂载目录
VOLUME /home/ruoyi

# 创建目录
RUN mkdir -p /home/ruoyi

# 指定路径
WORKDIR /home/ruoyi

# 复制jar文件到路径
COPY ruoyi-admin/target/ruoyi-admin.jar /home/ruoyi/ruoyi-admin.jar

# 启动系统服务
ENTRYPOINT ["java","-jar","ruoyi-admin.jar"]
