# 仅用JRE8运行JAR，无需任何Maven镜像
FROM openjdk:8-jre-alpine
WORKDIR /app
# 复制Jenkins流水线中打包好的JAR包（路径和流水线一致）
COPY ./ruoyi-admin/target/ruoyi-admin.jar app.jar
# 暴露端口
EXPOSE 8080
# 启动命令（可加JVM参数优化）
CMD ["java", "-Xms256m", "-Xmx512m", "-jar", "app.jar"]