# 基础镜像
# 使用专门为ARM64架构构建的Java 8镜像
FROM arm64v8/openjdk:8-jre-alpine

# 作者
MAINTAINER ruoyi

# 安装字体和依赖
RUN apk add --no-cache ttf-dejavu fontconfig

# 挂载目录
VOLUME /home/ruoyi

# 创建目录
RUN mkdir -p /home/ruoyi

# 指定路径
WORKDIR /home/ruoyi

# 复制jar文件到路径
COPY ruoyi-admin/target/ruoyi-admin.jar /home/ruoyi/ruoyi-admin.jar

# 启动系统服务
ENTRYPOINT ["java","-Dserver.port=8080","-jar","ruoyi-admin.jar"]
