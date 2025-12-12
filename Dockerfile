# 替换为阿里云的openjdk 8-jre-alpine镜像（国内稳定）
FROM eclipse-temurin:8-jre
WORKDIR /app
COPY ./ruoyi-admin/target/ruoyi-admin.jar app.jar
EXPOSE 8080
# 启动命令（可加JVM参数优化）
CMD ["java", "-Xms256m", "-Xmx512m", "-jar", "app.jar"]